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
    /// Node bounds in canvas coordinates.
    public let bounds: CanvasBounds
    /// Additional key-value metadata.
    public let metadata: [String: String]

    /// Creates a node value.
    /// - Parameters:
    ///   - id: Unique node identifier.
    ///   - kind: Semantic node kind.
    ///   - text: Optional node text.
    ///   - bounds: Immutable node bounds.
    ///   - metadata: Additional metadata attributes.
    public init(
        id: CanvasNodeID,
        kind: CanvasNodeKind,
        text: String?,
        bounds: CanvasBounds,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.bounds = bounds
        self.metadata = metadata
    }
}
