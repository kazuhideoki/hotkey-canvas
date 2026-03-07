// Background: Pipeline execution starts from command mutation outputs.
// Responsibility: Capture post-mutation graph and stage effects for coordinator gating.
import Domain

/// Application-layer DTO representing command mutation output before pipeline stages.
struct CanvasMutationResult: Equatable, Sendable {
    let graphBeforeMutation: CanvasGraph
    let graphAfterMutation: CanvasGraph
    let effects: CanvasMutationEffects
    let areaLayoutSeedNodeID: CanvasNodeID?
    let diagramAlignmentConstraint: CanvasDiagramAlignmentConstraint?

    init(
        graphBeforeMutation: CanvasGraph,
        graphAfterMutation: CanvasGraph,
        effects: CanvasMutationEffects,
        areaLayoutSeedNodeID: CanvasNodeID? = nil,
        diagramAlignmentConstraint: CanvasDiagramAlignmentConstraint? = nil
    ) {
        self.graphBeforeMutation = graphBeforeMutation
        self.graphAfterMutation = graphAfterMutation
        self.effects = effects
        self.areaLayoutSeedNodeID = areaLayoutSeedNodeID
        self.diagramAlignmentConstraint = diagramAlignmentConstraint
    }
}
