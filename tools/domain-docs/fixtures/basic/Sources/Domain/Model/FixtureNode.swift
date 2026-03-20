/// @domainDoc entity
public struct FixtureNode: Equatable, Sendable {
    public let id: FixtureNodeID
    public let children: [FixtureChild]

    public init(id: FixtureNodeID, children: [FixtureChild]) {
        self.id = id
        self.children = children
    }
}

public struct FixtureChild: Equatable, Sendable {
    public let ownerNodeID: FixtureNodeID

    public init(ownerNodeID: FixtureNodeID) {
        self.ownerNodeID = ownerNodeID
    }
}
