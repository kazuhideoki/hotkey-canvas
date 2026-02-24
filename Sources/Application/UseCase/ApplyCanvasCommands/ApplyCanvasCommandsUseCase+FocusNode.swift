// Background: Inline search and pointer interactions may need direct focus placement by node identifier.
// Responsibility: Update graph focus/selection to one explicit node without changing structure/layout.
import Domain

extension ApplyCanvasCommandsUseCase {
    /// Focuses one explicit node and normalizes selection to the focused node.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - nodeID: Node identifier to focus.
    /// - Returns: Mutation result with updated focus/selection, or no-op when already focused.
    func focusNode(in graph: CanvasGraph, nodeID: CanvasNodeID) -> CanvasMutationResult {
        guard graph.nodesByID[nodeID] != nil else {
            return noOpMutationResult(for: graph)
        }

        let nextSelectedNodeIDs = CanvasSelectionService.normalizedSelectedNodeIDs(
            from: [nodeID],
            in: graph,
            focusedNodeID: nodeID
        )
        guard
            graph.focusedNodeID != nodeID
                || graph.selectedNodeIDs != nextSelectedNodeIDs
        else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nodeID,
            selectedNodeIDs: nextSelectedNodeIDs,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: true
            )
        )
    }
}
