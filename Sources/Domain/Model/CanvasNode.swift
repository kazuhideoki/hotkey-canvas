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
    /// Attachment payloads rendered as non-text content of the node.
    public let attachments: [CanvasAttachment]
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
    ///   - attachments: Non-text attachment payloads.
    ///   - bounds: Immutable node bounds.
    ///   - metadata: Additional metadata attributes.
    ///   - markdownStyleEnabled: Whether markdown styling is applied in non-editing rendering.
    public init(
        id: CanvasNodeID,
        kind: CanvasNodeKind,
        text: String?,
        attachments: [CanvasAttachment] = [],
        bounds: CanvasBounds,
        metadata: [String: String] = [:],
        markdownStyleEnabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.attachments = attachments
        self.bounds = bounds
        self.metadata = metadata
        self.markdownStyleEnabled = markdownStyleEnabled
    }
}

extension CanvasNode {
    /// Returns first image file path rendered above text when present.
    public var primaryImageAttachmentFilePath: String? {
        attachments.first(where: { $0.placement == .aboveText && $0.imageFilePath != nil })?.imageFilePath
    }
}
