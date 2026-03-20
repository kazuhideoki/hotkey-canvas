/// @domainDoc identifierOf(FixtureNode)
public struct FixtureNodeID: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

