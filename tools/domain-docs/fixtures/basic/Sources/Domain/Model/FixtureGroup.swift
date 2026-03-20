public struct FixtureGroup: Equatable, Sendable {
    public let nodeIDs: Set<FixtureNodeID>

    public init(nodeIDs: Set<FixtureNodeID>) {
        self.nodeIDs = nodeIDs
    }
}

