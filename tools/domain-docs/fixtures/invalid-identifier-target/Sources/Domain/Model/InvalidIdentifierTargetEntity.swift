public struct InvalidIdentifierTargetEntity: Equatable, Sendable {
    public let id: InvalidIdentifierTargetID

    public init(id: InvalidIdentifierTargetID) {
        self.id = id
    }
}
