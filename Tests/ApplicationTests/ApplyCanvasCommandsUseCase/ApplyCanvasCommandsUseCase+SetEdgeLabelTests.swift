import Application
import Domain
import Testing

// Background: Edge inline editing writes labels through command pipeline.
// Responsibility: Verify setEdgeLabel mutation behavior and normalization.
@Test("ApplyCanvasCommandsUseCase: setEdgeLabel updates edge label and normalizes empty to nil")
func test_apply_setEdgeLabel_updatesEdgeLabel() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let edgeID = CanvasEdgeID(rawValue: "edge-a-b")
    let areaID = CanvasAreaID(rawValue: "area-diagram")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: makeSetEdgeLabelTestNode(id: nodeAID, x: 0, y: 0),
            nodeBID: makeSetEdgeLabelTestNode(id: nodeBID, x: 320, y: 0),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: nodeAID,
                toNodeID: nodeBID,
                relationType: .normal
            )
        ],
        focusedNodeID: nodeAID,
        focusedElement: .edge(CanvasEdgeFocus(edgeID: edgeID, originNodeID: nodeAID)),
        selectedEdgeIDs: [edgeID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeAID, nodeBID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let updated = try await sut.apply(
        commands: [.setEdgeLabel(edgeID: edgeID, label: "flow")]
    )
    #expect(updated.newState.edgesByID[edgeID]?.label == "flow")

    let cleared = try await sut.apply(
        commands: [.setEdgeLabel(edgeID: edgeID, label: "")]
    )
    #expect(cleared.newState.edgesByID[edgeID]?.label == nil)
}

@Test("ApplyCanvasCommandsUseCase: setEdgeLabel is no-op when edge is missing")
func test_apply_setEdgeLabel_noOpWhenEdgeMissing() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let edgeID = CanvasEdgeID(rawValue: "edge-a-b")
    let missingEdgeID = CanvasEdgeID(rawValue: "edge-missing")
    let areaID = CanvasAreaID(rawValue: "area-diagram")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: makeSetEdgeLabelTestNode(id: nodeAID, x: 0, y: 0),
            nodeBID: makeSetEdgeLabelTestNode(id: nodeBID, x: 320, y: 0),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: nodeAID,
                toNodeID: nodeBID,
                relationType: .normal,
                label: "existing"
            )
        ],
        focusedNodeID: nodeAID,
        focusedElement: .edge(CanvasEdgeFocus(edgeID: edgeID, originNodeID: nodeAID)),
        selectedEdgeIDs: [edgeID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeAID, nodeBID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(
        commands: [.setEdgeLabel(edgeID: missingEdgeID, label: "flow")]
    )
    #expect(result.newState.edgesByID[edgeID]?.label == "existing")
}

private func makeSetEdgeLabelTestNode(id: CanvasNodeID, x: Double, y: Double) -> CanvasNode {
    CanvasNode(
        id: id,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: x, y: y, width: 220, height: 120)
    )
}
