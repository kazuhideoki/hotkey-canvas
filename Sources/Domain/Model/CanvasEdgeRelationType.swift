// Background: Edge semantics are extensible and should not be tied to enums yet.
// Responsibility: Represent relation type as a strongly typed raw value.
/// Relation semantics assigned to a graph edge.
public struct CanvasEdgeRelationType: RawRepresentable, Equatable, Hashable, Sendable {
    /// Underlying relation identifier.
    public let rawValue: String

    /// Creates a relation type from raw identifier text.
    /// - Parameter rawValue: Relation identifier payload.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Standard relation without extra hierarchy semantics.
    public static let normal = CanvasEdgeRelationType(rawValue: "normal")
    /// Parent-child relation used for hierarchical links.
    public static let parentChild = CanvasEdgeRelationType(rawValue: "parent-child")
}
