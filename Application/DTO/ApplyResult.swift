import Domain

public struct ApplyResult: Equatable, Sendable {
    public let newState: CanvasGraph

    public init(newState: CanvasGraph) {
        self.newState = newState
    }
}
