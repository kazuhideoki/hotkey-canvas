import Domain

struct SubtreeDeletionFixture {
    let rootID: CanvasNodeID
    let childID: CanvasNodeID
    let grandchildID: CanvasNodeID
    let siblingID: CanvasNodeID
    let edgeRootChildID: CanvasEdgeID
    let edgeChildGrandchildID: CanvasEdgeID
    let edgeRootSiblingID: CanvasEdgeID
    let nodesByID: [CanvasNodeID: CanvasNode]
    let edgesByID: [CanvasEdgeID: CanvasEdge]
}

extension SubtreeDeletionFixture {
    static func make() -> SubtreeDeletionFixture {
        let ids = FixtureIDs()

        return SubtreeDeletionFixture(
            rootID: ids.rootID,
            childID: ids.childID,
            grandchildID: ids.grandchildID,
            siblingID: ids.siblingID,
            edgeRootChildID: ids.edgeRootChildID,
            edgeChildGrandchildID: ids.edgeChildGrandchildID,
            edgeRootSiblingID: ids.edgeRootSiblingID,
            nodesByID: makeNodes(ids: ids),
            edgesByID: makeEdges(ids: ids)
        )
    }

    private static func makeNodes(ids: FixtureIDs) -> [CanvasNodeID: CanvasNode] {
        [
            ids.rootID: CanvasNode(
                id: ids.rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            ids.childID: CanvasNode(
                id: ids.childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 120, width: 100, height: 80)
            ),
            ids.grandchildID: CanvasNode(
                id: ids.grandchildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 240, width: 100, height: 80)
            ),
            ids.siblingID: CanvasNode(
                id: ids.siblingID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 0, width: 100, height: 80)
            ),
        ]
    }

    private static func makeEdges(ids: FixtureIDs) -> [CanvasEdgeID: CanvasEdge] {
        [
            ids.edgeRootChildID: CanvasEdge(
                id: ids.edgeRootChildID,
                fromNodeID: ids.rootID,
                toNodeID: ids.childID,
                relationType: .parentChild
            ),
            ids.edgeChildGrandchildID: CanvasEdge(
                id: ids.edgeChildGrandchildID,
                fromNodeID: ids.childID,
                toNodeID: ids.grandchildID,
                relationType: .parentChild
            ),
            ids.edgeRootSiblingID: CanvasEdge(
                id: ids.edgeRootSiblingID,
                fromNodeID: ids.rootID,
                toNodeID: ids.siblingID,
                relationType: .parentChild
            ),
        ]
    }
}

private struct FixtureIDs {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let grandchildID = CanvasNodeID(rawValue: "grandchild")
    let siblingID = CanvasNodeID(rawValue: "sibling")
    let edgeRootChildID = CanvasEdgeID(rawValue: "edge-root-child")
    let edgeChildGrandchildID = CanvasEdgeID(rawValue: "edge-child-grandchild")
    let edgeRootSiblingID = CanvasEdgeID(rawValue: "edge-root-sibling")
}
