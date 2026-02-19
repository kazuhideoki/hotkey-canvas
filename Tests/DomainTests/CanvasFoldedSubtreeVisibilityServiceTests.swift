import Domain
import Testing

@Test("CanvasFoldedSubtreeVisibilityService: descendantNodeIDs traverses parent-child edges")
func test_descendantNodeIDs_traversesParentChildEdges() {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let grandchildID = CanvasNodeID(rawValue: "grandchild")
    let graph = makeVisibilityGraph(rootID: rootID, childID: childID, grandchildID: grandchildID)

    let descendants = CanvasFoldedSubtreeVisibilityService.descendantNodeIDs(of: rootID, in: graph)

    #expect(descendants == [childID, grandchildID])
}

@Test("CanvasFoldedSubtreeVisibilityService: hiddenNodeIDs hides descendants but keeps root")
func test_hiddenNodeIDs_hidesDescendantsButKeepsRoot() {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let grandchildID = CanvasNodeID(rawValue: "grandchild")
    let graph = makeVisibilityGraph(
        rootID: rootID,
        childID: childID,
        grandchildID: grandchildID,
        collapsedRootNodeIDs: [rootID]
    )

    let hiddenNodeIDs = CanvasFoldedSubtreeVisibilityService.hiddenNodeIDs(in: graph)
    let visibleNodeIDs = CanvasFoldedSubtreeVisibilityService.visibleNodeIDs(in: graph)

    #expect(hiddenNodeIDs == [childID, grandchildID])
    #expect(visibleNodeIDs == [rootID])
}

@Test("CanvasFoldedSubtreeVisibilityService: normalizedCollapsedRootNodeIDs removes missing or leaf roots")
func test_normalizedCollapsedRootNodeIDs_removesMissingOrLeafRoots() {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let missingID = CanvasNodeID(rawValue: "missing")
    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 200, height: 100)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 300, y: 40, width: 200, height: 100)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootID,
        collapsedRootNodeIDs: [rootID, childID, missingID]
    )

    let normalizedCollapsedRootNodeIDs = CanvasFoldedSubtreeVisibilityService.normalizedCollapsedRootNodeIDs(
        in: graph
    )

    #expect(normalizedCollapsedRootNodeIDs == [rootID])
}

private func makeVisibilityGraph(
    rootID: CanvasNodeID,
    childID: CanvasNodeID,
    grandchildID: CanvasNodeID,
    collapsedRootNodeIDs: Set<CanvasNodeID> = []
) -> CanvasGraph {
    CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 200, height: 100)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 300, y: 40, width: 200, height: 100)
            ),
            grandchildID: CanvasNode(
                id: grandchildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 560, y: 40, width: 200, height: 100)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-child-grandchild"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-child-grandchild"),
                fromNodeID: childID,
                toNodeID: grandchildID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: rootID,
        collapsedRootNodeIDs: collapsedRootNodeIDs
    )
}
