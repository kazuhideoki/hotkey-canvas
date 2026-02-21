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

@Test("ApplyCanvasCommandsUseCase: diagram area rejects assignNodesToArea command")
func test_apply_diagramArea_rejectsAssignNodesToAreaCommand() async throws {
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

    do {
        _ = try await sut.apply(commands: [.assignNodesToArea(nodeIDs: [nodeID], areaID: targetAreaID)])
        Issue.record("Expected unsupported command error")
    } catch let error as CanvasAreaPolicyError {
        #expect(
            error
                == .unsupportedCommandInMode(
                    mode: .diagram,
                    command: .assignNodesToArea(nodeIDs: [nodeID], areaID: targetAreaID)
                ))
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
