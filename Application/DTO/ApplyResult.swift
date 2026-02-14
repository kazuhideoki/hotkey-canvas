import Domain

public struct ApplyResult: Equatable, Sendable {
    public let newState: CanvasGraph
    public let canUndo: Bool
    public let canRedo: Bool

    public init(newState: CanvasGraph, canUndo: Bool = false, canRedo: Bool = false) {
        self.newState = newState
        self.canUndo = canUndo
        self.canRedo = canRedo
    }
}
