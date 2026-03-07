import Domain

// Background: Copy/cut/paste requires a temporary in-memory representation independent from graph identifiers.
// Responsibility: Represent one copied node-set payload used for paste reconstruction in tree/diagram areas.
/// Clipboard payload for copied nodes and internal edges.
struct CanvasClipboardPayload: Equatable, Sendable {
    /// Copied node payloads keyed by stable source references.
    let nodes: [CanvasClipboardNodePayload]
    /// Copied edges whose endpoints are included in `nodes`.
    let edges: [CanvasClipboardEdgePayload]
    /// Source references treated as roots when pasting in tree mode.
    let rootNodeReferenceIDs: [String]

}

/// Node payload for clipboard reconstruction.
struct CanvasClipboardNodePayload: Equatable, Sendable {
    /// Stable source reference used to rebuild edge endpoints.
    let sourceReferenceID: String
    /// Node kind to preserve semantic type on paste.
    let kind: CanvasNodeKind
    /// Optional text payload to preserve editor content.
    let text: String?
    /// Attachment payloads to preserve non-text node content on paste.
    let attachments: [CanvasAttachment]
    /// Whether markdown styling is enabled for the node.
    let markdownStyleEnabled: Bool
    /// Metadata payload copied from source node.
    let metadata: [String: String]
    /// Source-node bounds used for relative placement.
    let bounds: CanvasBounds

}

/// Edge payload for clipboard reconstruction.
struct CanvasClipboardEdgePayload: Equatable, Sendable {
    /// Source node reference for edge origin.
    let fromSourceReferenceID: String
    /// Source node reference for edge destination.
    let toSourceReferenceID: String
    /// Edge semantic relation type.
    let relationType: CanvasEdgeRelationType
    /// Edge arrow direction relative to endpoint references.
    let directionality: CanvasEdgeDirectionality
    /// Stable sibling order used for `parentChild` edges.
    let parentChildOrder: Int?

    /// Creates a clipboard edge payload.
    /// - Parameters:
    ///   - fromSourceReferenceID: Source reference for `from` endpoint.
    ///   - toSourceReferenceID: Source reference for `to` endpoint.
    ///   - relationType: Edge relation.
    ///   - directionality: Edge arrow direction.
    ///   - parentChildOrder: Stable sibling order for `parentChild` edges.
    init(
        fromSourceReferenceID: String,
        toSourceReferenceID: String,
        relationType: CanvasEdgeRelationType,
        directionality: CanvasEdgeDirectionality = .none,
        parentChildOrder: Int? = nil
    ) {
        self.fromSourceReferenceID = fromSourceReferenceID
        self.toSourceReferenceID = toSourceReferenceID
        self.relationType = relationType
        self.directionality = directionality
        self.parentChildOrder = parentChildOrder
    }
}
