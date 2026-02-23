import Domain

// Background: Copy/cut/paste requires a temporary in-memory representation independent from graph identifiers.
// Responsibility: Represent one copied node-set payload used for paste reconstruction in tree/diagram areas.
/// Clipboard payload for copied nodes and internal edges.
public struct CanvasClipboardPayload: Equatable, Sendable {
    /// Copied node payloads keyed by stable source references.
    public let nodes: [CanvasClipboardNodePayload]
    /// Copied edges whose endpoints are included in `nodes`.
    public let edges: [CanvasClipboardEdgePayload]
    /// Source references treated as roots when pasting in tree mode.
    public let rootNodeReferenceIDs: [String]

    /// Creates a clipboard payload.
    /// - Parameters:
    ///   - nodes: Copied node payloads.
    ///   - edges: Copied internal edges.
    ///   - rootNodeReferenceIDs: Root references for tree-mode parent attachment.
    public init(
        nodes: [CanvasClipboardNodePayload],
        edges: [CanvasClipboardEdgePayload],
        rootNodeReferenceIDs: [String]
    ) {
        self.nodes = nodes
        self.edges = edges
        self.rootNodeReferenceIDs = rootNodeReferenceIDs
    }
}

/// Node payload for clipboard reconstruction.
public struct CanvasClipboardNodePayload: Equatable, Sendable {
    /// Stable source reference used to rebuild edge endpoints.
    public let sourceReferenceID: String
    /// Node kind to preserve semantic type on paste.
    public let kind: CanvasNodeKind
    /// Optional text payload to preserve editor content.
    public let text: String?
    /// Attachment payloads to preserve non-text node content on paste.
    public let attachments: [CanvasAttachment]
    /// Whether markdown styling is enabled for the node.
    public let markdownStyleEnabled: Bool
    /// Metadata payload copied from source node.
    public let metadata: [String: String]
    /// Source-node bounds used for relative placement.
    public let bounds: CanvasBounds

    /// Creates a clipboard node payload.
    /// - Parameters:
    ///   - sourceReferenceID: Source node reference.
    ///   - kind: Semantic node kind.
    ///   - text: Optional node text.
    ///   - attachments: Node attachment payloads.
    ///   - markdownStyleEnabled: Markdown style flag for rendering.
    ///   - metadata: Node metadata dictionary.
    ///   - bounds: Source node bounds.
    public init(
        sourceReferenceID: String,
        kind: CanvasNodeKind,
        text: String?,
        attachments: [CanvasAttachment],
        markdownStyleEnabled: Bool,
        metadata: [String: String],
        bounds: CanvasBounds
    ) {
        self.sourceReferenceID = sourceReferenceID
        self.kind = kind
        self.text = text
        self.attachments = attachments
        self.markdownStyleEnabled = markdownStyleEnabled
        self.metadata = metadata
        self.bounds = bounds
    }
}

/// Edge payload for clipboard reconstruction.
public struct CanvasClipboardEdgePayload: Equatable, Sendable {
    /// Source node reference for edge origin.
    public let fromSourceReferenceID: String
    /// Source node reference for edge destination.
    public let toSourceReferenceID: String
    /// Edge semantic relation type.
    public let relationType: CanvasEdgeRelationType

    /// Creates a clipboard edge payload.
    /// - Parameters:
    ///   - fromSourceReferenceID: Source reference for `from` endpoint.
    ///   - toSourceReferenceID: Source reference for `to` endpoint.
    ///   - relationType: Edge relation.
    public init(
        fromSourceReferenceID: String,
        toSourceReferenceID: String,
        relationType: CanvasEdgeRelationType
    ) {
        self.fromSourceReferenceID = fromSourceReferenceID
        self.toSourceReferenceID = toSourceReferenceID
        self.relationType = relationType
    }
}
