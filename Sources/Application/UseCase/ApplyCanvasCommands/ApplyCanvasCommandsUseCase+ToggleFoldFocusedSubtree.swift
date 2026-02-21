import Domain

// Background: Folding a focused subtree should be represented as an undoable graph-state transition.
// Responsibility: Toggle collapsed state for descendants under the currently focused node.
extension ApplyCanvasCommandsUseCase {
    /// Toggles collapsed-root membership of the focused node without triggering layout stages.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Mutation result with updated collapsed-root set, or no-op when not applicable.
    func toggleFoldFocusedSubtree(in graph: CanvasGraph) -> CanvasMutationResult {
        guard let focusedNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard graph.nodesByID[focusedNodeID] != nil else {
            return noOpMutationResult(for: graph)
        }
        guard CanvasFoldedSubtreeVisibilityService.hasDescendants(of: focusedNodeID, in: graph) else {
            return noOpMutationResult(for: graph)
        }

        var nextCollapsedRootNodeIDs =
            CanvasFoldedSubtreeVisibilityService.normalizedCollapsedRootNodeIDs(in: graph)
        if nextCollapsedRootNodeIDs.contains(focusedNodeID) {
            nextCollapsedRootNodeIDs.remove(focusedNodeID)
        } else {
            nextCollapsedRootNodeIDs.insert(focusedNodeID)
        }

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            collapsedRootNodeIDs: nextCollapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: false
            )
        )
    }
}
