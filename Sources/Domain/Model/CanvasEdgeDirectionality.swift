// Background: Edge endpoints (`from`/`to`) already exist.
// Arrow rendering may be disabled or reversed by user intent.
// Responsibility: Represent edge arrow direction relative to stored endpoints.
/// Arrow direction state assigned to an edge.
public struct CanvasEdgeDirectionality: RawRepresentable, Equatable, Hashable, Sendable {
    /// Underlying directionality identifier.
    public let rawValue: String

    /// Creates directionality from a raw identifier.
    /// - Parameter rawValue: Directionality identifier payload.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// No arrow is rendered for the edge.
    public static let none = CanvasEdgeDirectionality(rawValue: "none")
    /// Arrow points from `fromNodeID` to `toNodeID`.
    public static let fromTo = CanvasEdgeDirectionality(rawValue: "from-to")
    /// Arrow points from `toNodeID` to `fromNodeID`.
    public static let toFrom = CanvasEdgeDirectionality(rawValue: "to-from")
}
