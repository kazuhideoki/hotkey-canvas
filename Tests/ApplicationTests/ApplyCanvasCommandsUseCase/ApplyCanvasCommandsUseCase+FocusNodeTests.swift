import Application
import Domain
import Testing

// Background: Search exit flow needs deterministic focus handoff to a specific node.
// Responsibility: Verify explicit focus command updates focused node and selection.
@Test("ApplyCanvasCommandsUseCase: focusNode moves focus and collapses selection")
func test_apply_focusNode_movesFocusAndSelection() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: CanvasNode(
                id: nodeAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            nodeBID: CanvasNode(
                id: nodeBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 160, y: 0, width: 100, height: 80)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: nodeAID,
        selectedNodeIDs: [nodeAID, nodeBID]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.focusNode(nodeBID)])

    #expect(result.newState.focusedNodeID == nodeBID)
    #expect(result.newState.selectedNodeIDs == [nodeBID])
}

@Test("ApplyCanvasCommandsUseCase: focusNode keeps focused node but normalizes selection")
func test_apply_focusNode_normalizesSelectionWhenFocusAlreadyMatches() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: CanvasNode(
                id: nodeAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            nodeBID: CanvasNode(
                id: nodeBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 160, y: 0, width: 100, height: 80)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: nodeBID,
        selectedNodeIDs: [nodeAID, nodeBID]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.focusNode(nodeBID)])

    #expect(result.newState.focusedNodeID == nodeBID)
    #expect(result.newState.selectedNodeIDs == [nodeBID])
}
