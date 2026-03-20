/// @domainDoc identifierOf(InferredPropertyChild)
public struct InferredPropertyChildID: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
