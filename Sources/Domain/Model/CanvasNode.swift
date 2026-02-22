// Background: Node entities carry layout and content without framework dependencies.
// Responsibility: Represent one immutable node value inside the graph.
/// Immutable node entity for canvas graph state.
public struct CanvasNode: Equatable, Sendable {
    /// Unique node identifier.
    public let id: CanvasNodeID
    /// Semantic node kind.
    public let kind: CanvasNodeKind
    /// Optional text payload associated with the node.
    public let text: String?
    /// Optional image file path rendered above text inside the node.
    public let imagePath: String?
    /// Node bounds in canvas coordinates.
    public let bounds: CanvasBounds
    /// Additional key-value metadata.
    public let metadata: [String: String]
    /// Whether committed rendering applies markdown styling rules.
    public let markdownStyleEnabled: Bool

    /// Creates a node value.
    /// - Parameters:
    ///   - id: Unique node identifier.
    ///   - kind: Semantic node kind.
    ///   - text: Optional node text.
    ///   - imagePath: Optional image file path displayed in the node.
    ///   - bounds: Immutable node bounds.
    ///   - metadata: Additional metadata attributes.
    ///   - markdownStyleEnabled: Whether markdown styling is applied in non-editing rendering.
    public init(
        id: CanvasNodeID,
        kind: CanvasNodeKind,
        text: String?,
        imagePath: String? = nil,
        bounds: CanvasBounds,
        metadata: [String: String] = [:],
        markdownStyleEnabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imagePath = imagePath
        self.bounds = bounds
        self.metadata = metadata
        self.markdownStyleEnabled = markdownStyleEnabled
    }
}
