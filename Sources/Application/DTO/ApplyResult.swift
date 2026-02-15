// Background: Canvas apply operations must expose both resulting graph state and UI-driving metadata.
// Responsibility: Represent the application-layer result of command application and history availability.
import Domain

public struct ApplyResult: Equatable, Sendable {
    public let newState: CanvasGraph
    public let canUndo: Bool
    public let canRedo: Bool
    /// `true` when the apply operation introduced at least one new node into the graph.
    public let didAddNode: Bool

    public init(
        newState: CanvasGraph,
        canUndo: Bool = false,
        canRedo: Bool = false,
        didAddNode: Bool = false
    ) {
        self.newState = newState
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.didAddNode = didAddNode
    }
}
