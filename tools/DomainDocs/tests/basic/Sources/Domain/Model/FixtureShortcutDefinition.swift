/// @domainDoc entity
public struct FixtureShortcutDefinition: Equatable, Sendable {
    public let id: FixtureShortcutID

    public init(id: FixtureShortcutID) {
        self.id = id
    }
}
