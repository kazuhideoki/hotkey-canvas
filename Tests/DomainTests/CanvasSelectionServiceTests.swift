import Domain
import Testing

@Test("正規化された選択はフォーカス中のノードを維持し、非表示の子孫を削除する")
func test_normalizedSelectedNodeIDs_keepsFocusedAndDropsHiddenNode() {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let hiddenDescendantID = CanvasNodeID(rawValue: "hidden")
    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 60)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 180, y: 0, width: 120, height: 60)
            ),
            hiddenDescendantID: CanvasNode(
                id: hiddenDescendantID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 360, y: 0, width: 120, height: 60)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-child-hidden"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-child-hidden"),
                fromNodeID: childID,
                toNodeID: hiddenDescendantID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: childID,
        selectedNodeIDs: [childID, hiddenDescendantID],
        collapsedRootNodeIDs: [childID]
    )

    let normalized = CanvasSelectionService.normalizedSelectedNodeIDs(in: graph)

    #expect(normalized == [childID])
}

@Test("フォーカス中のノードが nil の場合、正規化された選択は空になる")
func test_normalizedSelectedNodeIDs_becomesEmptyWhenFocusedNodeIsNil() {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 60)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nil,
        selectedNodeIDs: [nodeID]
    )

    let normalized = CanvasSelectionService.normalizedSelectedNodeIDs(in: graph)

    #expect(normalized.isEmpty)
}

@Test("正規化されたエッジ選択は、焦点を合わせたエッジを維持し、欠落したエッジを削除する")
func test_normalizedSelectedEdgeIDs_keepsFocusedAndDropsMissing() {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let missingEdgeID = CanvasEdgeID(rawValue: "missing-edge")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: CanvasNode(
                id: nodeAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 60)
            ),
            nodeBID: CanvasNode(
                id: nodeBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 220, y: 0, width: 120, height: 60)
            ),
        ],
        edgesByID: [
            edgeABID: CanvasEdge(
                id: edgeABID,
                fromNodeID: nodeAID,
                toNodeID: nodeBID,
                relationType: .normal
            )
        ],
        focusedElement: .edge(CanvasEdgeFocus(edgeID: edgeABID, originNodeID: nodeAID)),
        selectedEdgeIDs: [edgeABID, missingEdgeID]
    )

    let normalized = CanvasSelectionService.normalizedSelectedEdgeIDs(in: graph)

    #expect(normalized == [edgeABID])
}
