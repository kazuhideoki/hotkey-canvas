import Domain

// Background: Placement helpers need deterministic edge ordering when multiple anchors are possible.
// Responsibility: Rank candidate edges for placement-anchor selection.
extension ApplyCanvasCommandsUseCase {
    /// Returns deterministic edge priority for placement anchor selection.
    func isPreferredPlacementAnchorEdge(_ lhs: CanvasEdge, _ rhs: CanvasEdge) -> Bool {
        let lhsPriority = edgePriorityForPlacementAnchor(lhs)
        let rhsPriority = edgePriorityForPlacementAnchor(rhs)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    /// Defines edge priority so normal links are used before structural links.
    func edgePriorityForPlacementAnchor(_ edge: CanvasEdge) -> Int {
        if edge.relationType == .normal {
            return 0
        }
        if edge.relationType == .parentChild {
            return 1
        }
        return 2
    }
}
