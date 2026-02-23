import Domain

// Background: Copy/cut/paste requires a temporary in-memory representation independent from graph identifiers.
// Responsibility: Represent one copied subtree payload used for paste reconstruction.
/// Clipboard payload for one copied tree subtree.
public struct CanvasTreeClipboardPayload: Equatable, Sendable {
    /// Root node payload including descendants in deterministic child order.
    public let rootNode: CanvasTreeClipboardNodePayload

    /// Creates a clipboard payload.
    /// - Parameter rootNode: Root node payload.
    public init(rootNode: CanvasTreeClipboardNodePayload) {
        self.rootNode = rootNode
    }
}

/// Node payload for clipboard subtree representation.
public struct CanvasTreeClipboardNodePayload: Equatable, Sendable {
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
    /// Child node payloads in visual order.
    public let children: [CanvasTreeClipboardNodePayload]

    /// Creates a clipboard node payload.
    /// - Parameters:
    ///   - kind: Semantic node kind.
    ///   - text: Optional node text.
    ///   - attachments: Node attachment payloads.
    ///   - markdownStyleEnabled: Markdown style flag for rendering.
    ///   - metadata: Node metadata dictionary.
    ///   - children: Child payload list in deterministic order.
    public init(
        kind: CanvasNodeKind,
        text: String?,
        attachments: [CanvasAttachment],
        markdownStyleEnabled: Bool,
        metadata: [String: String],
        children: [CanvasTreeClipboardNodePayload]
    ) {
        self.kind = kind
        self.text = text
        self.attachments = attachments
        self.markdownStyleEnabled = markdownStyleEnabled
        self.metadata = metadata
        self.children = children
    }
}
