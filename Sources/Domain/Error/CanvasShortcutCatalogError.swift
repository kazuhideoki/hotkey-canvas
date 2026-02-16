// Background: Shortcut catalog integrity must be validated when definitions are assembled.
// Responsibility: Describe validation failures for shortcut catalog construction.
/// Validation failures for shortcut catalog definitions.
public enum CanvasShortcutCatalogError: Error, Equatable, Sendable {
    case emptyID(CanvasShortcutID)
    case emptyName(CanvasShortcutID)
    case emptyShortcutLabel(CanvasShortcutID)
    case emptySearchToken(CanvasShortcutID)
    case duplicateID(CanvasShortcutID)
    case duplicateGesture(CanvasShortcutGesture)
}
