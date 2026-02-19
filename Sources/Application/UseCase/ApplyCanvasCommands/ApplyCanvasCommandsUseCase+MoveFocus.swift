import Domain

// Background: Keyboard-driven navigation needs deterministic next-focus selection.
// Responsibility: Resolve next focus by delegating directional candidate selection to domain service.
extension ApplyCanvasCommandsUseCase {
    func moveFocus(in graph: CanvasGraph, direction: CanvasFocusDirection) -> CanvasMutationResult {
        let visibleGraph = CanvasFoldedSubtreeVisibilityService.visibleGraph(from: graph)
        guard
            let nextFocusedNodeID = CanvasFocusNavigationService.nextFocusedNodeID(
                in: visibleGraph,
                moving: direction
            )
        else {
            return noOpMutationResult(for: graph)
        }

        guard graph.focusedNodeID != nextFocusedNodeID else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nextFocusedNodeID,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs
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
