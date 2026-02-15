import Domain

// Background: Sibling creation requires parent lookup from the focused child node.
// Responsibility: Create a new sibling under the same parent and focus it.
extension ApplyCanvasCommandsUseCase {
    /// Adds a sibling node under the same parent as the currently focused node.
    /// - Parameter graph: Current canvas graph.
    /// - Returns: Updated graph focused on the newly created sibling node,
    ///   or the original graph when creation is not applicable.
    /// - Throws: Propagates graph mutation errors from node or edge creation.
    func addSiblingNode(in graph: CanvasGraph) throws -> CanvasGraph {
        guard let focusedNodeID = graph.focusedNodeID else {
            return graph
        }
        guard graph.nodesByID[focusedNodeID] != nil else {
            return graph
        }
        guard let parentID = parentNodeID(of: focusedNodeID, in: graph) else {
            return graph
        }
        guard graph.nodesByID[parentID] != nil else {
            return graph
        }

        let siblingAreaNodeIDs = parentChildAreaNodeIDs(containing: parentID, in: graph)
        let siblingNode = makeTextNode(
            bounds: makeAvailableNewNodeBounds(in: graph, avoiding: siblingAreaNodeIDs)
        )

        var graphWithSibling = try CanvasGraphCRUDService.createNode(siblingNode, in: graph)
        graphWithSibling = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: parentID, to: siblingNode.id),
            in: graphWithSibling
        )
        let graphAfterLayout = resolveAreaOverlaps(around: siblingNode.id, in: graphWithSibling)

        return CanvasGraph(
            nodesByID: graphAfterLayout.nodesByID,
            edgesByID: graphAfterLayout.edgesByID,
            focusedNodeID: siblingNode.id
        )
    }
}
