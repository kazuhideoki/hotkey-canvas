// Background: Shortcut gestures carry modifier keys independent from UI frameworks.
// Responsibility: Represent shortcut modifiers in a domain-friendly, hashable form.
/// Modifier-key set used by shortcut gestures.
public struct CanvasShortcutModifiers: OptionSet, Equatable, Hashable, Sendable {
    /// Bitmask raw value.
    public let rawValue: UInt8

    /// Command key modifier.
    public static let command = CanvasShortcutModifiers(rawValue: 1 << 0)
    /// Shift key modifier.
    public static let shift = CanvasShortcutModifiers(rawValue: 1 << 1)
    /// Option key modifier.
    public static let option = CanvasShortcutModifiers(rawValue: 1 << 2)
    /// Control key modifier.
    public static let control = CanvasShortcutModifiers(rawValue: 1 << 3)
    /// Function key modifier.
    public static let function = CanvasShortcutModifiers(rawValue: 1 << 4)

    /// Creates a modifier set from a bitmask.
    /// - Parameter rawValue: Bitmask payload.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}
