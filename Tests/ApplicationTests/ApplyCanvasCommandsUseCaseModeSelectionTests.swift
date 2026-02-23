import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: mode-selected add-node is undoable in one step")
func test_addNodeFromModeSelection_isUndoableInOneStep() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    let applied = try await sut.addNodeFromModeSelection(mode: .diagram)
    #expect(applied.newState.nodesByID.count == 1)
    #expect(applied.canUndo)
    let focusedNodeID = try #require(applied.newState.focusedNodeID)
    let addedNode = try #require(applied.newState.nodesByID[focusedNodeID])
    #expect(addedNode.bounds.width == 220)
    #expect(addedNode.bounds.height == 220)

    let undone = await sut.undo()
    #expect(undone.newState == .empty)
    #expect(!undone.canUndo)
    #expect(undone.canRedo)
}

@Test("ApplyCanvasCommandsUseCase: mode-selected add-node works after deleting all nodes with multiple empty areas")
func test_addNodeFromModeSelection_worksAfterDeletingAllNodes() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    let firstAdd = try await sut.addNodeFromModeSelection(mode: .diagram)
    let firstNodeID = try #require(firstAdd.newState.focusedNodeID)
    let firstNodeAreaMode = try #require(modeOfAreaContaining(nodeID: firstNodeID, in: firstAdd.newState))
    #expect(firstNodeAreaMode == .diagram)

    _ = try await sut.apply(commands: [.deleteFocusedNode])
    let deletedState = await sut.getCurrentResult()
    #expect(deletedState.newState.nodesByID.isEmpty)

    let secondAdd = try await sut.addNodeFromModeSelection(mode: .diagram)
    let secondNodeID = try #require(secondAdd.newState.focusedNodeID)
    let secondNodeAreaMode = try #require(modeOfAreaContaining(nodeID: secondNodeID, in: secondAdd.newState))
    #expect(secondNodeAreaMode == .diagram)
    #expect(secondAdd.newState.nodesByID.count == 1)
}

@Test("ApplyCanvasCommandsUseCase: empty graph mode-selected add-node picks selected tree mode area")
func test_addNodeFromModeSelection_emptyGraphRespectsSelectedTreeMode() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.addNodeFromModeSelection(mode: .diagram)
    _ = try await sut.apply(commands: [.deleteFocusedNode])

    let applied = try await sut.addNodeFromModeSelection(mode: .tree)
    let focusedNodeID = try #require(applied.newState.focusedNodeID)
    let areaMode = try #require(modeOfAreaContaining(nodeID: focusedNodeID, in: applied.newState))
    #expect(areaMode == .tree)
}

@Test("ApplyCanvasCommandsUseCase: mode-selected new diagram does not connect from existing diagram")
func test_addNodeFromModeSelection_newDiagramDoesNotCreateEdgeFromExistingDiagram() async throws {
    let existingNodeID = CanvasNodeID(rawValue: "existing-diagram-node")
    let existingAreaID = CanvasAreaID(rawValue: "diagram-area-existing")
    let initialGraph = CanvasGraph(
        nodesByID: [
            existingNodeID: CanvasNode(
                id: existingNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 220)
            )
        ],
        edgesByID: [:],
        focusedNodeID: existingNodeID,
        areasByID: [
            existingAreaID: CanvasArea(id: existingAreaID, nodeIDs: [existingNodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: initialGraph)

    let applied = try await sut.addNodeFromModeSelection(mode: .diagram)

    #expect(applied.newState.nodesByID.count == 2)
    #expect(applied.newState.edgesByID.isEmpty)
    let addedNodeID = try #require(applied.newState.focusedNodeID)
    #expect(addedNodeID != existingNodeID)
    let existingNodeAreaMode = try #require(modeOfAreaContaining(nodeID: existingNodeID, in: applied.newState))
    let addedNodeAreaMode = try #require(modeOfAreaContaining(nodeID: addedNodeID, in: applied.newState))
    #expect(existingNodeAreaMode == .diagram)
    #expect(addedNodeAreaMode == .diagram)
    #expect(
        areaIDContaining(nodeID: existingNodeID, in: applied.newState)
            != areaIDContaining(nodeID: addedNodeID, in: applied.newState))
}

@Test("ApplyCanvasCommandsUseCase: mode-selected new tree does not connect from existing diagram")
func test_addNodeFromModeSelection_newTreeDoesNotCreateCrossAreaEdge() async throws {
    let existingNodeID = CanvasNodeID(rawValue: "existing-diagram-node")
    let existingAreaID = CanvasAreaID(rawValue: "diagram-area-existing")
    let initialGraph = CanvasGraph(
        nodesByID: [
            existingNodeID: CanvasNode(
                id: existingNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 220)
            )
        ],
        edgesByID: [:],
        focusedNodeID: existingNodeID,
        areasByID: [
            existingAreaID: CanvasArea(id: existingAreaID, nodeIDs: [existingNodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: initialGraph)

    let applied = try await sut.addNodeFromModeSelection(mode: .tree)

    #expect(applied.newState.nodesByID.count == 2)
    #expect(applied.newState.edgesByID.isEmpty)
    let addedNodeID = try #require(applied.newState.focusedNodeID)
    let addedNodeAreaMode = try #require(modeOfAreaContaining(nodeID: addedNodeID, in: applied.newState))
    #expect(addedNodeAreaMode == .tree)
}

@Test("ApplyCanvasCommandsUseCase: mode-selected new diagram avoids overlap when graph is non-empty and focus is nil")
func test_addNodeFromModeSelection_newDiagramAvoidsOverlapWhenFocusIsNil() async throws {
    let existingNodeID = CanvasNodeID(rawValue: "existing-diagram-node")
    let existingAreaID = CanvasAreaID(rawValue: "diagram-area-existing")
    let initialGraph = CanvasGraph(
        nodesByID: [
            existingNodeID: CanvasNode(
                id: existingNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 220)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nil,
        areasByID: [
            existingAreaID: CanvasArea(id: existingAreaID, nodeIDs: [existingNodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: initialGraph)

    let applied = try await sut.addNodeFromModeSelection(mode: .diagram)

    let addedNodeID = try #require(applied.newState.focusedNodeID)
    let addedNode = try #require(applied.newState.nodesByID[addedNodeID])
    let existingNode = try #require(applied.newState.nodesByID[existingNodeID])
    #expect(boundsOverlap(addedNode.bounds, existingNode.bounds) == false)
}

private func modeOfAreaContaining(nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasEditingMode? {
    graph.areasByID.values
        .sorted(by: { $0.id.rawValue < $1.id.rawValue })
        .first(where: { $0.nodeIDs.contains(nodeID) })?
        .editingMode
}

private func areaIDContaining(nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasAreaID? {
    graph.areasByID.values
        .sorted(by: { $0.id.rawValue < $1.id.rawValue })
        .first(where: { $0.nodeIDs.contains(nodeID) })?
        .id
}

private func boundsOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds) -> Bool {
    let lhsRight = lhs.x + lhs.width
    let lhsBottom = lhs.y + lhs.height
    let rhsRight = rhs.x + rhs.width
    let rhsBottom = rhs.y + rhs.height
    return lhs.x < rhsRight
        && lhsRight > rhs.x
        && lhs.y < rhsBottom
        && lhsBottom > rhs.y
}
