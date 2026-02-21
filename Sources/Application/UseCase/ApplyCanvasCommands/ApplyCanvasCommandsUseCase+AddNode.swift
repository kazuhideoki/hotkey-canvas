import Domain

// Background: Adding a node is one of the baseline editing actions in the canvas workflow.
// Responsibility: Insert a new text node at an available position and move focus to it.
extension ApplyCanvasCommandsUseCase {
    /// Creates one top-level text node and marks only area layout as required for follow-up stages.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Mutation result focused on the newly created node.
    /// - Throws: Propagates node creation failure from CRUD service.
    func addNode(in graph: CanvasGraph, areaID: CanvasAreaID) throws -> CanvasMutationResult {
        let node = makeTextNode(bounds: makeAvailableNewNodeBounds(in: graph))
        var graphAfterMutation = try CanvasGraphCRUDService.createNode(node, in: graph).get()
        graphAfterMutation = try CanvasAreaMembershipService.assign(
            nodeIDs: Set([node.id]),
            to: areaID,
            in: graphAfterMutation
        ).get()
        let nextGraph = CanvasGraph(
            nodesByID: graphAfterMutation.nodesByID,
            edgesByID: graphAfterMutation.edgesByID,
            focusedNodeID: node.id,
            collapsedRootNodeIDs: graphAfterMutation.collapsedRootNodeIDs,
            areasByID: graphAfterMutation.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: node.id
        )
    }
}
