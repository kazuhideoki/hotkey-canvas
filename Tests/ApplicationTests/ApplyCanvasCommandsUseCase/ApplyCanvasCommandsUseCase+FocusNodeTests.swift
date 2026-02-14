import Application
import Domain
import Testing

// Background: Direct focus commands are used by adapters to target specific nodes.
// Responsibility: Verify focus updates only when the target node exists.
@Test("ApplyCanvasCommandsUseCase: focusNode sets focused node when node exists")
func test_apply_focusNode_setsFocusedNode_whenNodeExists() async throws {
    let firstID = CanvasNodeID(rawValue: "first")
    let secondID = CanvasNodeID(rawValue: "second")
    let graph = CanvasGraph(
        nodesByID: [
            firstID: CanvasNode(
                id: firstID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            ),
            secondID: CanvasNode(
                id: secondID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 120, y: 0, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: firstID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.focusNode(secondID)])

    #expect(result.newState.focusedNodeID == secondID)
}

@Test("ApplyCanvasCommandsUseCase: focusNode is no-op when node does not exist")
func test_apply_focusNode_isNoOp_whenNodeDoesNotExist() async throws {
    let firstID = CanvasNodeID(rawValue: "first")
    let missingID = CanvasNodeID(rawValue: "missing")
    let graph = CanvasGraph(
        nodesByID: [
            firstID: CanvasNode(
                id: firstID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: firstID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.focusNode(missingID)])

    #expect(result.newState == graph)
}
