// Background: Command handlers still execute through legacy paths during pipeline migration.
// Responsibility: Capture post-mutation graph and phase-1-fixed effects for stage gating.
import Domain

/// Application-layer DTO representing command mutation output before pipeline stages.
public struct CanvasMutationResult: Equatable, Sendable {
    public let graphBeforeMutation: CanvasGraph
    public let graphAfterMutation: CanvasGraph
    public let effects: CanvasMutationEffects

    public init(
        graphBeforeMutation: CanvasGraph,
        graphAfterMutation: CanvasGraph,
        effects: CanvasMutationEffects
    ) {
        self.graphBeforeMutation = graphBeforeMutation
        self.graphAfterMutation = graphAfterMutation
        self.effects = effects
    }
}

extension CanvasMutationResult {
    static func classify(
        command: CanvasCommand,
        graphBeforeMutation: CanvasGraph,
        graphAfterMutation: CanvasGraph
    ) -> CanvasMutationResult {
        let didMutateGraph = graphBeforeMutation != graphAfterMutation
        guard didMutateGraph else {
            return CanvasMutationResult(
                graphBeforeMutation: graphBeforeMutation,
                graphAfterMutation: graphAfterMutation,
                effects: .noEffect
            )
        }

        let effects: CanvasMutationEffects
        switch command {
        case .addNode:
            effects = CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: true,
                needsFocusNormalization: false
            )
        case .addChildNode, .addSiblingNode, .moveNode, .setNodeText:
            effects = CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: true,
                needsFocusNormalization: false
            )
        case .deleteFocusedNode:
            effects = CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: graphAfterMutation.focusedNodeID != nil,
                needsFocusNormalization: true
            )
        case .moveFocus:
            effects = CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: true
            )
        }

        return CanvasMutationResult(
            graphBeforeMutation: graphBeforeMutation,
            graphAfterMutation: graphAfterMutation,
            effects: effects
        )
    }
}
