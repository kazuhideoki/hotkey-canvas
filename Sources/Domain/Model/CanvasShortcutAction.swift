// Background: Shortcut definitions trigger domain/application intentions.
// Responsibility: Express supported actions invoked from shortcut input.
/// Action resolved from a shortcut gesture.
public enum CanvasShortcutAction: Equatable, Sendable {
    case apply(commands: [CanvasCommand])
    case undo
    case redo
    case zoomIn
    case zoomOut
    case openCommandPalette
}
