/// @domainDoc identifierOf(MissingTargetEntity)
public struct InvalidIdentifierTargetID: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
