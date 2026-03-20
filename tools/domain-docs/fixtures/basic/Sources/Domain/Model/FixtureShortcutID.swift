/// @domainDoc identifierOf(FixtureShortcutDefinition)
public struct FixtureShortcutID: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

