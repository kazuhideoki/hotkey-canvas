import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: undo restores previous graph after addNode")
func test_undo_restoresPreviousGraph_afterAddNode() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    let applied = try await sut.apply(commands: [.addNode])
    #expect(applied.newState.nodesByID.count == 1)
    #expect(applied.canUndo)
    #expect(!applied.canRedo)

    let undone = await sut.undo()
    #expect(undone.newState == .empty)
    #expect(!undone.canUndo)
    #expect(undone.canRedo)
}

@Test("ApplyCanvasCommandsUseCase: redo reapplies state after undo")
func test_redo_reappliesState_afterUndo() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.apply(commands: [.addNode])
    _ = await sut.undo()
    let redone = await sut.redo()

    #expect(redone.newState.nodesByID.count == 1)
    #expect(redone.canUndo)
    #expect(!redone.canRedo)
}

@Test("ApplyCanvasCommandsUseCase: new apply clears redo history")
func test_apply_clearsRedoHistory_afterUndo() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.apply(commands: [.addNode])
    _ = await sut.undo()
    let reapplied = try await sut.apply(commands: [.addNode])
    #expect(!reapplied.canRedo)

    let redoResult = await sut.redo()
    #expect(redoResult.newState == reapplied.newState)
    #expect(!redoResult.canRedo)
}

@Test("ApplyCanvasCommandsUseCase: maxHistoryCount limits undo depth")
func test_undo_respectsMaxHistoryCount() async throws {
    let sut = ApplyCanvasCommandsUseCase(maxHistoryCount: 1)

    _ = try await sut.apply(commands: [.addNode])
    _ = try await sut.apply(commands: [.addNode])
    let firstUndo = await sut.undo()
    #expect(firstUndo.newState.nodesByID.count == 1)
    #expect(!firstUndo.canUndo)

    let secondUndo = await sut.undo()
    #expect(secondUndo.newState.nodesByID.count == 1)
}

@Test("ApplyCanvasCommandsUseCase: undo does not emit viewport intent when focus changes")
func test_undo_doesNotEmitViewportIntent_whenFocusChanges() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.apply(commands: [.addNode])
    _ = try await sut.apply(commands: [.addNode])
    let undone = await sut.undo()

    #expect(undone.newState.focusedNodeID != nil)
    #expect(undone.viewportIntent == nil)
}

@Test("ApplyCanvasCommandsUseCase: redo does not emit viewport intent when focus changes")
func test_redo_doesNotEmitViewportIntent_whenFocusChanges() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.apply(commands: [.addNode])
    _ = try await sut.apply(commands: [.addNode])
    _ = await sut.undo()
    let redone = await sut.redo()

    #expect(redone.newState.focusedNodeID != nil)
    #expect(redone.viewportIntent == nil)
}

@Test("ApplyCanvasCommandsUseCase: undo/redo restores area membership after assignNodesToArea")
func test_undoRedo_restoresAreaMembership_afterAssignNodesToArea() async throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let sourceAreaID = CanvasAreaID(rawValue: "source")
    let targetAreaID = CanvasAreaID(rawValue: "target")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            sourceAreaID: CanvasArea(id: sourceAreaID, nodeIDs: [nodeID], editingMode: .diagram),
            targetAreaID: CanvasArea(id: targetAreaID, nodeIDs: [], editingMode: .tree),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let applied = try await sut.apply(commands: [.assignNodesToArea(nodeIDs: [nodeID], areaID: targetAreaID)])
    #expect(applied.newState.areasByID[targetAreaID]?.nodeIDs.contains(nodeID) == true)
    #expect(applied.canUndo)

    let undone = await sut.undo()
    #expect(undone.newState.areasByID[sourceAreaID]?.nodeIDs.contains(nodeID) == true)
    #expect(undone.newState.areasByID[targetAreaID]?.nodeIDs.contains(nodeID) == false)
    #expect(undone.canRedo)

    let redone = await sut.redo()
    #expect(redone.newState.areasByID[targetAreaID]?.nodeIDs.contains(nodeID) == true)
    #expect(redone.newState.areasByID[sourceAreaID]?.nodeIDs.contains(nodeID) == false)
}

@Test("ApplyCanvasCommandsUseCase: failed assignNodesToArea does not append undo history")
func test_failedAssignNodesToArea_doesNotAppendUndoHistory() async throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeID = CanvasEdgeID(rawValue: "edge-parent-child")
    let sourceAreaID = CanvasAreaID(rawValue: "source")
    let targetAreaID = CanvasAreaID(rawValue: "target")
    let graph = CanvasGraph(
        nodesByID: [
            parentID: CanvasNode(
                id: parentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 80)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 260, y: 0, width: 200, height: 80)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: parentID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: parentID,
        areasByID: [
            sourceAreaID: CanvasArea(id: sourceAreaID, nodeIDs: [parentID, childID], editingMode: .diagram),
            targetAreaID: CanvasArea(id: targetAreaID, nodeIDs: [], editingMode: .tree),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    do {
        _ = try await sut.apply(commands: [.assignNodesToArea(nodeIDs: [childID], areaID: targetAreaID)])
        Issue.record("Expected crossAreaEdgeForbidden")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .crossAreaEdgeForbidden(edgeID))
    }

    let undoResult = await sut.undo()
    #expect(undoResult.newState == graph)
    #expect(!undoResult.canUndo)
}

@Test("ApplyCanvasCommandsUseCase: undo/redo restores area mode after convertFocusedAreaMode")
func test_undoRedo_restoresAreaMode_afterConvertFocusedAreaMode() async throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let areaID = CanvasAreaID(rawValue: "area-1")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let converted = try await sut.apply(commands: [.convertFocusedAreaMode(to: .diagram)])
    #expect(converted.newState.areasByID[areaID]?.editingMode == .diagram)
    #expect(converted.canUndo)

    let undone = await sut.undo()
    #expect(undone.newState.areasByID[areaID]?.editingMode == .tree)
    #expect(undone.canRedo)

    let redone = await sut.redo()
    #expect(redone.newState.areasByID[areaID]?.editingMode == .diagram)
}

@Test("ApplyCanvasCommandsUseCase: same-mode convertFocusedAreaMode does not append undo history")
func test_sameModeConvertFocusedAreaMode_doesNotAppendUndoHistory() async throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let areaID = CanvasAreaID(rawValue: "area-1")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.convertFocusedAreaMode(to: .diagram)])
    #expect(!result.canUndo)

    let undoResult = await sut.undo()
    #expect(undoResult.newState == graph)
    #expect(!undoResult.canUndo)
}
