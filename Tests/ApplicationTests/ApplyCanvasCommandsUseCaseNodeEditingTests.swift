import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: setNodeText updates target node, normalizes empty to nil, and persists height")
func test_apply_setNodeText_updatesNodeText() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let updated = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "after", nodeHeight: 48)]
    )
    #expect(updated.newState.nodesByID[nodeID]?.text == "after")
    #expect(updated.newState.nodesByID[nodeID]?.bounds.height == 48)

    let cleared = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "", nodeHeight: 44)]
    )
    #expect(cleared.newState.nodesByID[nodeID]?.text == nil)
    #expect(cleared.newState.nodesByID[nodeID]?.bounds.height == 44)
}
