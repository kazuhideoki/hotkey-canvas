// Background: Pipeline execution starts from command mutation outputs.
// Responsibility: Capture post-mutation graph and stage effects for coordinator gating.
import Domain

/// Application-layer DTO representing command mutation output before pipeline stages.
public struct CanvasMutationResult: Equatable, Sendable {
    public let graphBeforeMutation: CanvasGraph
    public let graphAfterMutation: CanvasGraph
    public let effects: CanvasMutationEffects
    public let areaLayoutSeedNodeID: CanvasNodeID?

    public init(
        graphBeforeMutation: CanvasGraph,
        graphAfterMutation: CanvasGraph,
        effects: CanvasMutationEffects,
        areaLayoutSeedNodeID: CanvasNodeID? = nil
    ) {
        self.graphBeforeMutation = graphBeforeMutation
        self.graphAfterMutation = graphAfterMutation
        self.effects = effects
        self.areaLayoutSeedNodeID = areaLayoutSeedNodeID
    }
}
