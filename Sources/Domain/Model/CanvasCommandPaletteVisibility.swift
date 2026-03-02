// Background: Command palette must hide commands that cannot execute in the current editing context.
// Responsibility: Define visibility requirements for each shortcut entry in command palette listing.
/// Visibility policy for one command palette shortcut definition.
public enum CanvasCommandPaletteVisibility: Equatable, Sendable {
    case always
    case requiresFocusedNode
    case requiresMode(Set<CanvasEditingMode>)
    case requiresFocusedNodeAndMode(Set<CanvasEditingMode>)
}

extension CanvasCommandPaletteVisibility {
    var defaultExecutionCondition: KeymapExecutionCondition {
        switch self {
        case .always:
            .always
        case .requiresFocusedNode:
            .requiresFocusedNode
        case .requiresMode(let modes):
            .requiredModes(modes)
        case .requiresFocusedNodeAndMode(let modes):
            .all([.requiresFocusedNode, .requiredModes(modes)])
        }
    }
}
