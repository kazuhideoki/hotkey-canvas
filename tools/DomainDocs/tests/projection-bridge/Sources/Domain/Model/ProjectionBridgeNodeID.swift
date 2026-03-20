/// @domainDoc identifierOf(ProjectionBridgeNode)
public struct ProjectionBridgeNodeID: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
