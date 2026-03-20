public struct InferredPropertyEntity: Equatable, Sendable {
    public let childIDs = Set<InferredPropertyChildID>()

    public init() {}
}

public struct InferredPropertyChild: Equatable, Sendable {
    public let id: InferredPropertyChildID

    public init(id: InferredPropertyChildID) {
        self.id = id
    }
}
