import Application
import Domain
import Testing

// Background: Diagram mode now supports explicit connection between existing nodes.
// Responsibility: Verify connect-nodes command behavior and mode-policy boundaries.
@Test("ApplyCanvasCommandsUseCase: connectNodes creates one normal edge in diagram area")
func test_apply_connectNodesInDiagramArea_createsNormalEdge() async throws {
    let sourceNodeID = CanvasNodeID(rawValue: "source")
    let targetNodeID = CanvasNodeID(rawValue: "target")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            sourceNodeID: CanvasNode(
                id: sourceNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 220)
            ),
            targetNodeID: CanvasNode(
                id: targetNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 400, y: 40, width: 220, height: 220)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: sourceNodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [sourceNodeID, targetNodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(
        commands: [.connectNodes(fromNodeID: sourceNodeID, toNodeID: targetNodeID)]
    )

    #expect(result.newState.edgesByID.count == 1)
    let createdEdge = try #require(result.newState.edgesByID.values.first)
    #expect(createdEdge.fromNodeID == sourceNodeID)
    #expect(createdEdge.toNodeID == targetNodeID)
    #expect(createdEdge.relationType == .normal)
}

@Test("ApplyCanvasCommandsUseCase: connectNodes is no-op when the same edge already exists")
func test_apply_connectNodes_whenNormalEdgeAlreadyExists_isNoOp() async throws {
    let sourceNodeID = CanvasNodeID(rawValue: "source")
    let targetNodeID = CanvasNodeID(rawValue: "target")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let existingEdgeID = CanvasEdgeID(rawValue: "edge-existing")
    let graph = CanvasGraph(
        nodesByID: [
            sourceNodeID: CanvasNode(
                id: sourceNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 220)
            ),
            targetNodeID: CanvasNode(
                id: targetNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 400, y: 40, width: 220, height: 220)
            ),
        ],
        edgesByID: [
            existingEdgeID: CanvasEdge(
                id: existingEdgeID,
                fromNodeID: sourceNodeID,
                toNodeID: targetNodeID,
                relationType: .normal
            )
        ],
        focusedNodeID: sourceNodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [sourceNodeID, targetNodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(
        commands: [.connectNodes(fromNodeID: sourceNodeID, toNodeID: targetNodeID)]
    )

    #expect(result.newState == graph)
}

@Test("ApplyCanvasCommandsUseCase: tree area rejects connectNodes command")
func test_apply_connectNodesInTreeArea_throwsUnsupportedCommandError() async throws {
    let sourceNodeID = CanvasNodeID(rawValue: "source")
    let targetNodeID = CanvasNodeID(rawValue: "target")
    let areaID = CanvasAreaID(rawValue: "tree-area")
    let graph = CanvasGraph(
        nodesByID: [
            sourceNodeID: CanvasNode(
                id: sourceNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            ),
            targetNodeID: CanvasNode(
                id: targetNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 400, y: 40, width: 220, height: 120)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: sourceNodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [sourceNodeID, targetNodeID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)
    let command = CanvasCommand.connectNodes(fromNodeID: sourceNodeID, toNodeID: targetNodeID)

    do {
        _ = try await sut.apply(commands: [command])
        Issue.record("Expected unsupported command error")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .unsupportedCommandInMode(mode: .tree, command: command))
    }
}
