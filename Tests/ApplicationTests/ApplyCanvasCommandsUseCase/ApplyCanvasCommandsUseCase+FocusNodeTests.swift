import Application
import Domain
import Testing

// Background: Search exit flow needs deterministic focus handoff to a specific node.
// Responsibility: Verify explicit focus command updates focused node and selection.
@Test("focusNode はフォーカスを移動し、選択範囲を折りたたみます")
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

@Test("focusNode はフォーカス中のノードを維持するが、選択を正規化する")
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

@Test("focusNode は、フォーカス中のノードがすでに一致している場合でもエリア フォーカスをクリアする")
func test_apply_focusNode_clearsAreaFocusWhenFocusedNodeAlreadyMatches() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let areaID = CanvasAreaID(rawValue: "area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        focusedElement: .area(areaID),
        selectedNodeIDs: [nodeID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let commands: [CanvasCommand] = [.focusNode(nodeID)]
    let result = try await sut.apply(commands: commands)

    #expect(result.newState.focusedNodeID == nodeID)
    #expect(result.newState.focusedElement == .node(nodeID))
    #expect(result.newState.selectedNodeIDs == [nodeID])
}
