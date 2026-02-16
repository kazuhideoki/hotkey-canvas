// Background: Shortcut definitions need stable identifiers for deterministic lookup and testing.
// Responsibility: Provide a strongly typed identifier for shortcut catalog entries.
/// Opaque identifier for a canvas shortcut definition.
public struct CanvasShortcutID: RawRepresentable, Equatable, Hashable, Sendable {
    /// Underlying string value.
    public let rawValue: String

    /// Creates an identifier from a raw string.
    /// - Parameter rawValue: Identifier payload.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
