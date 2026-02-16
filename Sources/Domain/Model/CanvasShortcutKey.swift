// Background: Shortcut matching requires a canonical representation of key input.
// Responsibility: Model supported key variants for shortcut gestures.
/// Key value used in a shortcut gesture.
public enum CanvasShortcutKey: Equatable, Hashable, Sendable {
    case enter
    case deleteBackward
    case deleteForward
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case character(String)
}
