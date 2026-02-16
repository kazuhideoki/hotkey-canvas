// Background: Shortcut resolution compares incoming input against catalog gestures.
// Responsibility: Hold key plus modifiers as a stable matching unit.
/// Canonical gesture used for shortcut lookup.
public struct CanvasShortcutGesture: Equatable, Hashable, Sendable {
    /// Primary key input.
    public let key: CanvasShortcutKey
    /// Active modifier keys.
    public let modifiers: CanvasShortcutModifiers

    /// Creates a shortcut gesture.
    /// - Parameters:
    ///   - key: Primary key input.
    ///   - modifiers: Active modifier keys.
    public init(key: CanvasShortcutKey, modifiers: CanvasShortcutModifiers) {
        self.key = key
        self.modifiers = modifiers
    }
}
