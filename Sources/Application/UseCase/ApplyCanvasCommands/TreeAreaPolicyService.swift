import Domain

// Background: Tree mode keeps all existing command behaviors during phase-1 migration.
// Responsibility: Define command support matrix for tree areas.
enum TreeAreaPolicyService {
    /// Returns whether a command is supported by tree policy.
    /// - Parameter command: Command to evaluate.
    /// - Returns: `true` when command is allowed in tree areas.
    static func supports(_ command: CanvasCommand) -> Bool {
        switch command {
        case .addNode,
            .addChildNode,
            .addSiblingNode,
            .moveFocus,
            .moveNode,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .deleteFocusedNode,
            .setNodeText,
            .toggleFocusedNodeMarkdownStyle,
            .convertFocusedAreaMode,
            .createArea,
            .assignNodesToArea:
            return true
        }
    }
}
