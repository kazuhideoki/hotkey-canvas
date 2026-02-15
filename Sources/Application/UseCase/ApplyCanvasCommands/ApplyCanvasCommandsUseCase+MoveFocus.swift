import Domain

// Background: Keyboard-driven navigation needs deterministic next-focus selection.
// Responsibility: Resolve next focus by delegating directional candidate selection to domain service.
extension ApplyCanvasCommandsUseCase {
    func moveFocus(in graph: CanvasGraph, direction: CanvasFocusDirection) -> CanvasGraph {
        guard
            let nextFocusedNodeID = CanvasFocusNavigationService.nextFocusedNodeID(
                in: graph,
                moving: direction
            )
        else {
            return graph
        }

        guard graph.focusedNodeID != nextFocusedNodeID else {
            return graph
        }

        return CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nextFocusedNodeID
        )
    }
}
