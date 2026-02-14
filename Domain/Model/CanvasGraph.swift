public struct CanvasGraph: Equatable, Sendable {
    public let nodesByID: [CanvasNodeID: CanvasNode]
    public let edgesByID: [CanvasEdgeID: CanvasEdge]

    public init(
        nodesByID: [CanvasNodeID: CanvasNode] = [:],
        edgesByID: [CanvasEdgeID: CanvasEdge] = [:]
    ) {
        self.nodesByID = nodesByID
        self.edgesByID = edgesByID
    }

    public static let empty = CanvasGraph()
}
