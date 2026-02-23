// Background: Node attachments need stable identities for deterministic updates and reordering.
// Responsibility: Strongly typed identifier for canvas node attachments.
/// Opaque identifier value for a `CanvasAttachment`.
public struct CanvasAttachmentID: RawRepresentable, Equatable, Hashable, Sendable {
    /// Underlying string value.
    public let rawValue: String

    /// Creates an attachment identifier from a raw string.
    /// - Parameter rawValue: Identifier payload.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
