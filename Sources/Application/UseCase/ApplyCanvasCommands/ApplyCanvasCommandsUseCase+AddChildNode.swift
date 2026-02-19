import Domain

// Background: Child creation extends the focused node into a parent-child structure.
// Responsibility: Create a child node and connect it to the focused parent with a parent-child edge.
extension ApplyCanvasCommandsUseCase {
    /// Adds a child node to the currently focused node and resolves area-level overlap.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - requiresTopLevelParent: When `true`, child creation is allowed only for top-level parents.
    /// - Returns: Updated graph focused on the newly created child node,
    ///   or the original graph when creation is not applicable.
    /// - Throws: Propagates graph mutation errors from node or edge creation.
    func addChildNode(in graph: CanvasGraph, requiresTopLevelParent: Bool) throws -> CanvasMutationResult {
        guard let parentID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard let parentNode = graph.nodesByID[parentID] else {
            return noOpMutationResult(for: graph)
        }
        if requiresTopLevelParent && !isTopLevelParent(parentID, in: graph) {
            return noOpMutationResult(for: graph)
        }

        let siblingAreaNodeIDs = parentChildAreaNodeIDs(containing: parentID, in: graph)
        let childNode = makeTextNode(
            bounds: calculateChildBounds(for: parentNode, in: graph, avoiding: siblingAreaNodeIDs)
        )

        var graphWithChild = try CanvasGraphCRUDService.createNode(childNode, in: graph).get()
        graphWithChild = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: parentID, to: childNode.id),
            in: graphWithChild
        ).get()
        var nextCollapsedRootNodeIDs = graphWithChild.collapsedRootNodeIDs
        nextCollapsedRootNodeIDs.remove(parentID)
        let nextGraph = CanvasGraph(
            nodesByID: graphWithChild.nodesByID,
            edgesByID: graphWithChild.edgesByID,
            focusedNodeID: childNode.id,
            collapsedRootNodeIDs: nextCollapsedRootNodeIDs
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: childNode.id
        )
    }
}
