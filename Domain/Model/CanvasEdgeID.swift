// Background: IDs are wrapped to prevent mixing arbitrary strings in domain APIs.
// Responsibility: Strongly typed identifier for canvas edges.
/// Opaque identifier value for a `CanvasEdge`.
public struct CanvasEdgeID: RawRepresentable, Equatable, Hashable, Sendable {
    /// Underlying string value.
    public let rawValue: String

    /// Creates an edge identifier from a raw string.
    /// - Parameter rawValue: Identifier payload.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
