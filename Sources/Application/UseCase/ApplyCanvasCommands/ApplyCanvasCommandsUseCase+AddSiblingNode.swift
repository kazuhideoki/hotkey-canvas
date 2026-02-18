import Domain

// Background: Sibling creation requires parent lookup from the focused child node.
// Responsibility: Create a new sibling under the same parent and focus it.
extension ApplyCanvasCommandsUseCase {
    /// Adds a sibling node under the same parent as the currently focused node.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - position: Relative placement from the focused node.
    /// - Returns: Updated graph focused on the newly created sibling node,
    ///   or the original graph when creation is not applicable.
    /// - Throws: Propagates graph mutation errors from node or edge creation.
    func addSiblingNode(in graph: CanvasGraph, position: CanvasSiblingNodePosition) throws -> CanvasMutationResult {
        guard let focusedNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return noOpMutationResult(for: graph)
        }
        guard let parentID = parentNodeID(of: focusedNodeID, in: graph) else {
            return noOpMutationResult(for: graph)
        }
        guard graph.nodesByID[parentID] != nil else {
            return noOpMutationResult(for: graph)
        }

        let siblingNode = makeTextNode(
            bounds: makeSiblingNodeBounds(
                in: graph,
                parentID: parentID,
                focusedNode: focusedNode,
                position: position
            )
        )

        var graphWithSibling = try CanvasGraphCRUDService.createNode(siblingNode, in: graph).get()
        graphWithSibling = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: parentID, to: siblingNode.id),
            in: graphWithSibling
        ).get()
        let nextGraph = CanvasGraph(
            nodesByID: graphWithSibling.nodesByID,
            edgesByID: graphWithSibling.edgesByID,
            focusedNodeID: siblingNode.id
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
            areaLayoutSeedNodeID: siblingNode.id
        )
    }
}
