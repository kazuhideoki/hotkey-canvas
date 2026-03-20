/// @domainDoc identifierOf(ProjectionBridgeEdge)
public struct ProjectionBridgeEdgeID: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
