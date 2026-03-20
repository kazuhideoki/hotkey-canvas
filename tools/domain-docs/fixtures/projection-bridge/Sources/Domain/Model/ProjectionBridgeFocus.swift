public struct ProjectionBridgeEdgeFocus: Equatable, Sendable {
    public let edgeID: ProjectionBridgeEdgeID
    public let originNodeID: ProjectionBridgeNodeID

    public init(edgeID: ProjectionBridgeEdgeID, originNodeID: ProjectionBridgeNodeID) {
        self.edgeID = edgeID
        self.originNodeID = originNodeID
    }
}

public enum ProjectionBridgeFocus: Equatable, Sendable {
    case node(ProjectionBridgeNodeID)
    case edge(ProjectionBridgeEdgeFocus)
    case group(ProjectionBridgeGroupID)
}
