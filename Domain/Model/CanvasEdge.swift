public struct CanvasEdge: Equatable, Sendable {
    public let id: CanvasEdgeID
    public let fromNodeID: CanvasNodeID
    public let toNodeID: CanvasNodeID
    public let relationType: CanvasEdgeRelationType
    public let label: String?
    public let metadata: [String: String]

    public init(
        id: CanvasEdgeID,
        fromNodeID: CanvasNodeID,
        toNodeID: CanvasNodeID,
        relationType: CanvasEdgeRelationType = .normal,
        label: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.relationType = relationType
        self.label = label
        self.metadata = metadata
    }
}
