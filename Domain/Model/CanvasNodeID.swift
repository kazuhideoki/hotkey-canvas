// Background: IDs are wrapped to preserve type safety across domain APIs.
// Responsibility: Strongly typed identifier for canvas nodes.
/// Opaque identifier value for a `CanvasNode`.
public struct CanvasNodeID: RawRepresentable, Equatable, Hashable, Sendable {
    /// Underlying string value.
    public let rawValue: String

    /// Creates a node identifier from a raw string.
    /// - Parameter rawValue: Identifier payload.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
