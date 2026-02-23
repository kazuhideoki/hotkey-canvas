import Domain
import Testing

@Test("CanvasSelectionService: normalized selection keeps focused node and drops hidden descendants")
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

@Test("CanvasSelectionService: normalized selection becomes empty when focused node is nil")
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
