import Application
import Domain
import Testing

// Background: Phase-1 area mode requires command dispatch by focused area policy.
// Responsibility: Verify mode-specific command gating and area-data validation in apply entry.
@Test("ApplyCanvasCommandsUseCase: diagram area rejects unsupported command")
func test_apply_diagramArea_rejectsUnsupportedCommand() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    do {
        _ = try await sut.apply(commands: [.addChildNode])
        Issue.record("Expected unsupported command error")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .unsupportedCommandInMode(mode: .diagram, command: .addChildNode))
    }
}

@Test("ApplyCanvasCommandsUseCase: diagram area allows assignNodesToArea command")
func test_apply_diagramArea_allowsAssignNodesToAreaCommand() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram-area")
    let targetAreaID = CanvasAreaID(rawValue: "target-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [nodeID], editingMode: .diagram),
            targetAreaID: CanvasArea(id: targetAreaID, nodeIDs: [], editingMode: .tree),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.assignNodesToArea(nodeIDs: [nodeID], areaID: targetAreaID)])

    #expect(result.newState.areasByID[targetAreaID]?.nodeIDs == [nodeID])
    #expect(result.newState.areasByID[diagramAreaID]?.nodeIDs.isEmpty == true)
}

@Test("ApplyCanvasCommandsUseCase: diagram area allows createArea command")
func test_apply_diagramArea_allowsCreateAreaCommand() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram-area")
    let newAreaID = CanvasAreaID(rawValue: "new-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(
        commands: [
            .createArea(id: newAreaID, mode: .diagram, nodeIDs: [nodeID])
        ]
    )

    #expect(result.newState.areasByID[newAreaID]?.nodeIDs == [nodeID])
    #expect(result.newState.areasByID[diagramAreaID]?.nodeIDs.isEmpty == true)
}

@Test("ApplyCanvasCommandsUseCase: addNode fails when no focus and multiple areas exist")
func test_apply_addNode_failsWhenNoFocusAndMultipleAreasExist() async throws {
    let areaA = CanvasAreaID(rawValue: "area-a")
    let areaB = CanvasAreaID(rawValue: "area-b")
    let graph = CanvasGraph(
        nodesByID: [:],
        edgesByID: [:],
        focusedNodeID: nil,
        areasByID: [
            areaA: CanvasArea(id: areaA, nodeIDs: [], editingMode: .tree),
            areaB: CanvasArea(id: areaB, nodeIDs: [], editingMode: .diagram),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    do {
        _ = try await sut.apply(commands: [.addNode])
        Issue.record("Expected areaResolutionAmbiguousForAddNode")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .areaResolutionAmbiguousForAddNode)
    }
}

@Test("ApplyCanvasCommandsUseCase: apply fails when graph has nodes but no area data")
func test_apply_failsWhenAreaDataMissing() async throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [:]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    do {
        _ = try await sut.apply(commands: [.moveFocus(.right)])
        Issue.record("Expected areaDataMissing")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .areaDataMissing)
    }
}

@Test("ApplyCanvasCommandsUseCase: convertFocusedAreaMode converts focused area mode")
func test_apply_convertFocusedAreaMode_convertsFocusedAreaMode() async throws {
    let nodeID = CanvasNodeID(rawValue: "focused")
    let areaID = CanvasAreaID(rawValue: "area-1")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.convertFocusedAreaMode(to: .diagram)])

    #expect(result.newState.areasByID[areaID]?.editingMode == .diagram)
}
