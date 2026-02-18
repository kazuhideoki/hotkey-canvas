// Background: Coordinator execution needs a stable output contract independent from legacy apply details.
// Responsibility: Carry final graph and viewport intent after pipeline stage evaluation.
import Domain

/// Final output of command-pipeline execution.
public struct CanvasPipelineResult: Equatable, Sendable {
    public let graph: CanvasGraph
    public let viewportIntent: CanvasViewportIntent?
    public let didAddNode: Bool

    public init(
        graph: CanvasGraph,
        viewportIntent: CanvasViewportIntent?,
        didAddNode: Bool
    ) {
        self.graph = graph
        self.viewportIntent = viewportIntent
        self.didAddNode = didAddNode
    }
}
