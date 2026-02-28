import Application
import Domain
import Testing

// Background: Edge target deletion must remove only edges while preserving node graph state.
// Responsibility: Verify focused/selected edge deletion behavior for single and multi-selection flows.
@Test(
    "ApplyCanvasCommandsUseCase: deleteSelectedOrFocusedEdges deletes focused edge when focus is not in multi-selection"
)
func test_apply_deleteSelectedOrFocusedEdges_deletesFocusedEdge_whenFocusedEdgeIsNotInMultiSelection() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let edgeACID = CanvasEdgeID(rawValue: "edge-a-c")

    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: makeDeleteEdgeTestNode(id: nodeAID, x: 0, y: 0),
            nodeBID: makeDeleteEdgeTestNode(id: nodeBID, x: 300, y: 0),
            nodeCID: makeDeleteEdgeTestNode(id: nodeCID, x: 600, y: 0),
        ],
        edgesByID: [
            edgeABID: CanvasEdge(id: edgeABID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
            edgeACID: CanvasEdge(id: edgeACID, fromNodeID: nodeAID, toNodeID: nodeCID, relationType: .normal),
        ],
        focusedNodeID: nodeAID,
        focusedElement: .edge(CanvasEdgeFocus(edgeID: edgeABID, originNodeID: nodeAID)),
        selectedEdgeIDs: [edgeACID]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(
        commands: [
            .deleteSelectedOrFocusedEdges(
                focusedEdge: CanvasEdgeFocus(edgeID: edgeABID, originNodeID: nodeAID),
                selectedEdgeIDs: [edgeACID]
            )
        ]
    )

    #expect(result.newState.edgesByID[edgeABID] == nil)
    #expect(result.newState.edgesByID[edgeACID] != nil)
    #expect(result.newState.focusedNodeID == nodeAID)
    #expect(result.newState.selectedEdgeIDs == [edgeACID])

    guard case .edge(let focus) = result.newState.focusedElement else {
        Issue.record("Expected focused element to stay edge")
        return
    }
    #expect(focus.edgeID == edgeACID)
    #expect(focus.originNodeID == nodeAID)
}

@Test(
    "ApplyCanvasCommandsUseCase: deleteSelectedOrFocusedEdges deletes multi-selected edges"
)
func test_apply_deleteSelectedOrFocusedEdges_deletesMultiSelectedEdges_whenFocusedEdgeIsIncluded() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let edgeACID = CanvasEdgeID(rawValue: "edge-a-c")

    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: makeDeleteEdgeTestNode(id: nodeAID, x: 0, y: 0),
            nodeBID: makeDeleteEdgeTestNode(id: nodeBID, x: 300, y: 0),
            nodeCID: makeDeleteEdgeTestNode(id: nodeCID, x: 600, y: 0),
        ],
        edgesByID: [
            edgeABID: CanvasEdge(id: edgeABID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
            edgeACID: CanvasEdge(id: edgeACID, fromNodeID: nodeAID, toNodeID: nodeCID, relationType: .normal),
        ],
        focusedNodeID: nodeAID,
        focusedElement: .edge(CanvasEdgeFocus(edgeID: edgeABID, originNodeID: nodeAID)),
        selectedEdgeIDs: [edgeABID, edgeACID]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(
        commands: [
            .deleteSelectedOrFocusedEdges(
                focusedEdge: CanvasEdgeFocus(edgeID: edgeABID, originNodeID: nodeAID),
                selectedEdgeIDs: [edgeABID, edgeACID]
            )
        ]
    )

    #expect(result.newState.edgesByID.isEmpty)
    #expect(result.newState.focusedNodeID == nodeAID)
    #expect(result.newState.selectedEdgeIDs.isEmpty)
    #expect(result.newState.focusedElement == .node(nodeAID))
}

private func makeDeleteEdgeTestNode(id: CanvasNodeID, x: Double, y: Double) -> CanvasNode {
    CanvasNode(
        id: id,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: x, y: y, width: 220, height: 120)
    )
}
