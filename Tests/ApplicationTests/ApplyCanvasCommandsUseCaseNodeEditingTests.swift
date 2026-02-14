import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: focusNode sets focused node when target exists")
func test_apply_focusNode_updatesFocusedNode() async throws {
    let nodeAID = CanvasNodeID(rawValue: "a")
    let nodeBID = CanvasNodeID(rawValue: "b")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: CanvasNode(
                id: nodeAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            ),
            nodeBID: CanvasNode(
                id: nodeBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 120, y: 0, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeAID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.focusNode(nodeBID)])

    #expect(result.newState.focusedNodeID == nodeBID)
}

@Test("ApplyCanvasCommandsUseCase: setNodeText updates target node and normalizes empty to nil")
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

    let updated = try await sut.apply(commands: [.setNodeText(nodeID: nodeID, text: "after")])
    #expect(updated.newState.nodesByID[nodeID]?.text == "after")

    let cleared = try await sut.apply(commands: [.setNodeText(nodeID: nodeID, text: "")])
    #expect(cleared.newState.nodesByID[nodeID]?.text == nil)
}
