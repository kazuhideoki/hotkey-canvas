// Background: Node kinds may evolve and are represented as extensible raw values.
// Responsibility: Provide strongly typed semantic categories for nodes.
/// Semantic category assigned to a `CanvasNode`.
public struct CanvasNodeKind: RawRepresentable, Equatable, Hashable, Sendable {
    /// Underlying kind identifier.
    public let rawValue: String

    /// Creates a node kind from raw identifier text.
    /// - Parameter rawValue: Kind identifier payload.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Textual note node.
    public static let text = CanvasNodeKind(rawValue: "text")
    /// File reference node.
    public static let file = CanvasNodeKind(rawValue: "file")
    /// External link node.
    public static let link = CanvasNodeKind(rawValue: "link")
    /// Grouping container node.
    public static let group = CanvasNodeKind(rawValue: "group")
}
