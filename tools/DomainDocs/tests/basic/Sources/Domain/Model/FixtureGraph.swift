/// @domainDoc entity
public struct FixtureGraph: Equatable, Sendable {
    public let nodesByID: [FixtureNodeID: FixtureNode]
    public let selectedNodeIDs: Set<FixtureNodeID>
    public let shortcutsByID: [FixtureShortcutID: FixtureShortcutDefinition]

    public init(
        nodesByID: [FixtureNodeID: FixtureNode],
        selectedNodeIDs: Set<FixtureNodeID>,
        shortcutsByID: [FixtureShortcutID: FixtureShortcutDefinition]
    ) {
        self.nodesByID = nodesByID
        self.selectedNodeIDs = selectedNodeIDs
        self.shortcutsByID = shortcutsByID
    }
}
