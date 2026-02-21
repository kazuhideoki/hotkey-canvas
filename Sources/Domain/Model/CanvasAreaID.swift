// Background: Area IDs need strong typing to avoid mixing with node and edge IDs.
// Responsibility: Represent stable identifier values for canvas areas.
/// Opaque identifier value for a `CanvasArea`.
public struct CanvasAreaID: RawRepresentable, Equatable, Hashable, Sendable {
    /// Underlying string value.
    public let rawValue: String

    /// Creates an area identifier from a raw string.
    /// - Parameter rawValue: Identifier payload.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Default tree area used by initial empty graph snapshots.
    public static let defaultTree = CanvasAreaID(rawValue: "tree-default")
}
