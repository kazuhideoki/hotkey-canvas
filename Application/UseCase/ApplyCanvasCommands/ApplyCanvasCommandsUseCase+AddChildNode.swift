import Domain

// Background: Child creation extends the focused node into a parent-child structure.
// Responsibility: Create a child node and connect it to the focused parent with a parent-child edge.
extension ApplyCanvasCommandsUseCase {
    func addChildNode(in graph: CanvasGraph, requiresTopLevelParent: Bool) throws -> CanvasGraph {
        guard let parentID = graph.focusedNodeID else {
            return graph
        }
        guard let parentNode = graph.nodesByID[parentID] else {
            return graph
        }
        if requiresTopLevelParent && !isTopLevelParent(parentID, in: graph) {
            return graph
        }

        let childNode = makeTextNode(bounds: calculateChildBounds(for: parentNode, in: graph))

        var graphWithChild = try CanvasGraphCRUDService.createNode(childNode, in: graph)
        graphWithChild = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: parentID, to: childNode.id),
            in: graphWithChild
        )

        return CanvasGraph(
            nodesByID: graphWithChild.nodesByID,
            edgesByID: graphWithChild.edgesByID,
            focusedNodeID: childNode.id
        )
    }
}
