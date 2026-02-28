// Background: Command palette must hide commands that cannot execute in the current editing context.
// Responsibility: Define visibility requirements for each shortcut entry in command palette listing.
/// Visibility policy for one command palette shortcut definition.
public enum CanvasCommandPaletteVisibility: Equatable, Sendable {
    case always
    case requiresFocusedNode
    case requiresMode(Set<CanvasEditingMode>)
    case requiresFocusedNodeAndMode(Set<CanvasEditingMode>)
}
