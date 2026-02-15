import Domain

// Background: Sibling creation requires parent lookup from the focused child node.
// Responsibility: Create a new sibling under the same parent and focus it.
extension ApplyCanvasCommandsUseCase {
    func addSiblingNode(in graph: CanvasGraph, position: CanvasSiblingNodePosition) throws -> CanvasGraph {
        guard let focusedNodeID = graph.focusedNodeID else {
            return graph
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return graph
        }
        guard let parentID = parentNodeID(of: focusedNodeID, in: graph) else {
            return graph
        }
        guard graph.nodesByID[parentID] != nil else {
            return graph
        }

        let siblingNode = makeTextNode(
            bounds: makeSiblingNodeBounds(
                in: graph,
                focusedNode: focusedNode,
                position: position
            )
        )

        var graphWithSibling = try CanvasGraphCRUDService.createNode(siblingNode, in: graph)
        graphWithSibling = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: parentID, to: siblingNode.id),
            in: graphWithSibling
        )

        return CanvasGraph(
            nodesByID: graphWithSibling.nodesByID,
            edgesByID: graphWithSibling.edgesByID,
            focusedNodeID: siblingNode.id
        )
    }
}
