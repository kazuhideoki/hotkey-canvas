// Background: Global shortcuts must bypass primitive intent routing to avoid mixed responsibility.
// Responsibility: Express actions handled by global shortcut route.
/// Action emitted from global shortcut scope.
public enum KeymapGlobalAction: Equatable, Sendable {
    case openCommandPalette
    case openSearch
    case undo
    case redo
    case zoomIn
    case zoomOut
    case centerFocusedNode
}
