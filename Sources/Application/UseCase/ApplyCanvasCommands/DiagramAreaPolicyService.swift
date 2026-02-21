import Domain

// Background: Diagram mode intentionally starts with a reduced safe command set in phase 1.
// Responsibility: Define command support matrix for diagram areas.
enum DiagramAreaPolicyService {
    /// Returns whether a command is supported by phase-1 diagram policy.
    /// - Parameter command: Command to evaluate.
    /// - Returns: `true` when command is allowed in diagram areas.
    static func supports(_ command: CanvasCommand) -> Bool {
        switch command {
        case .moveFocus, .setNodeText, .centerFocusedNode:
            return true
        case .addNode,
            .addChildNode,
            .addSiblingNode,
            .moveNode,
            .toggleFoldFocusedSubtree,
            .deleteFocusedNode,
            .createArea,
            .assignNodesToArea:
            return false
        }
    }
}
