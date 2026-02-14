public struct CanvasNode: Equatable, Sendable {
    public let id: CanvasNodeID
    public let kind: CanvasNodeKind
    public let text: String?
    public let bounds: CanvasBounds
    public let metadata: [String: String]

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
