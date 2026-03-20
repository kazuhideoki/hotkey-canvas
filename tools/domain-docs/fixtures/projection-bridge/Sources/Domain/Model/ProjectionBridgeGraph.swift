/// @domainDoc entity
public struct ProjectionBridgeGraph: Equatable, Sendable {
    public let nodesByID: [ProjectionBridgeNodeID: ProjectionBridgeNode]
    public let edgesByID: [ProjectionBridgeEdgeID: ProjectionBridgeEdge]
    public let focus: ProjectionBridgeFocus?

    public init(
        nodesByID: [ProjectionBridgeNodeID: ProjectionBridgeNode],
        edgesByID: [ProjectionBridgeEdgeID: ProjectionBridgeEdge],
        focus: ProjectionBridgeFocus?
    ) {
        self.nodesByID = nodesByID
        self.edgesByID = edgesByID
        self.focus = focus
    }
}
