// Background: Coordinator execution needs a stable output contract independent from legacy apply details.
// Responsibility: Carry final graph and viewport intent after pipeline stage evaluation.
import Domain

/// Final output of command-pipeline execution.
struct CanvasPipelineResult: Equatable, Sendable {
    let graph: CanvasGraph
    let viewportIntent: CanvasViewportIntent?
    let didAddNode: Bool
}
