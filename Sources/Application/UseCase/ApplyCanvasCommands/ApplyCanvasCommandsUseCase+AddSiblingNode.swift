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
        graphWithSibling = normalizeParentChildOrder(for: parentID, in: graphWithSibling)
        let insertionOrder = siblingInsertionOrder(
            parentID: parentID,
            focusedNodeID: focusedNodeID,
            position: position,
            graph: graphWithSibling
        )
        graphWithSibling = shiftParentChildOrder(
            for: parentID,
            atOrAfter: insertionOrder,
            by: 1,
            in: graphWithSibling
        )
        graphWithSibling = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: parentID, to: siblingNode.id, order: insertionOrder),
            in: graphWithSibling
        ).get()
        let parentAreaID = try CanvasAreaMembershipService.areaID(containing: parentID, in: graphWithSibling).get()
        graphWithSibling = try CanvasAreaMembershipService.assign(
            nodeIDs: Set([siblingNode.id]),
            to: parentAreaID,
            in: graphWithSibling
        ).get()
        return makeAddSiblingMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: graphWithSibling,
            siblingNodeID: siblingNode.id
        )
    }

    private func siblingInsertionOrder(
        parentID: CanvasNodeID,
        focusedNodeID: CanvasNodeID,
        position: CanvasSiblingNodePosition,
        graph: CanvasGraph
    ) -> Int {
        let orderedEdges = parentChildEdges(of: parentID, in: graph)
        guard let focusedIndex = orderedEdges.firstIndex(where: { $0.toNodeID == focusedNodeID }) else {
            return nextParentChildOrder(for: parentID, in: graph)
        }
        switch position {
        case .above:
            return focusedIndex
        case .below:
            return focusedIndex + 1
        }
    }

    private func makeAddSiblingMutationResult(
        graphBeforeMutation: CanvasGraph,
        graphAfterMutation: CanvasGraph,
        siblingNodeID: CanvasNodeID
    ) -> CanvasMutationResult {
        let nextGraph = CanvasGraph(
            nodesByID: graphAfterMutation.nodesByID,
            edgesByID: graphAfterMutation.edgesByID,
            focusedNodeID: siblingNodeID,
            selectedNodeIDs: [siblingNodeID],
            collapsedRootNodeIDs: graphAfterMutation.collapsedRootNodeIDs,
            areasByID: graphAfterMutation.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graphBeforeMutation,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: siblingNodeID
        )
    }
}
