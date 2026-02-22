import Domain

// Background: Diagram mode in phase 2 expands only selected commands for mixed-canvas safety.
// Responsibility: Define command support matrix for diagram areas.
enum DiagramAreaPolicyService {
    /// Returns whether a command is supported by diagram policy.
    /// - Parameter command: Command to evaluate.
    /// - Returns: `true` when command is allowed in diagram areas.
    static func supports(_ command: CanvasCommand) -> Bool {
        switch command {
        case .addNode,
            .moveFocus,
            .moveNode,
            .centerFocusedNode,
            .deleteFocusedNode,
            .setNodeText,
            .convertFocusedAreaMode,
            .createArea,
            .assignNodesToArea:
            return true
        case .addChildNode,
            .addSiblingNode,
            .toggleFoldFocusedSubtree:
            return false
        }
    }
}
