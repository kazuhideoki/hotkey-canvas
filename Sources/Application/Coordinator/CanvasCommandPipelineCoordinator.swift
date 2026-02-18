// Background: Pipeline migration requires a centralized execution order without changing external behavior yet.
// Responsibility: Execute stage order in safe mode while preserving legacy command mutation output.
import Domain

/// Coordinator that evaluates fixed pipeline stage order from phase-1 effect contracts.
public struct CanvasCommandPipelineCoordinator: Sendable {
    public init() {}

    public func run(
        on baseGraph: CanvasGraph,
        mutationResults: [CanvasMutationResult]
    ) -> CanvasPipelineResult {
        var graph = baseGraph
        var lastViewportIntent: CanvasViewportIntent?

        for mutationResult in mutationResults {
            let graphBeforeMutation = graph
            let graphAfterStages = runStages(
                from: graphBeforeMutation,
                with: mutationResult
            )
            let viewportIntent = runViewportIntentStage(
                graphBeforeMutation: graphBeforeMutation,
                graphAfterPipeline: graphAfterStages
            )

            if let viewportIntent {
                lastViewportIntent = viewportIntent
            }
            graph = graphAfterStages
        }

        return CanvasPipelineResult(
            graph: graph,
            viewportIntent: lastViewportIntent,
            didAddNode: hasAddedNode(from: baseGraph, to: graph)
        )
    }
}

extension CanvasCommandPipelineCoordinator {
    private func runStages(
        from graphBeforeMutation: CanvasGraph,
        with mutationResult: CanvasMutationResult
    ) -> CanvasGraph {
        guard graphBeforeMutation == mutationResult.graphBeforeMutation else {
            // Safe mode fallback: preserve legacy graph when mutation chain is inconsistent.
            return mutationResult.graphAfterMutation
        }

        let effects = mutationResult.effects
        var graph = mutationResult.graphAfterMutation

        if effects.didMutateGraph && effects.needsTreeLayout {
            graph = runTreeLayoutStage(on: graph)
        }
        if effects.didMutateGraph && effects.needsAreaLayout {
            graph = runAreaLayoutStage(on: graph)
        }
        if effects.didMutateGraph && effects.needsFocusNormalization {
            graph = runFocusNormalizationStage(on: graph)
        }

        return graph
    }

    private func runTreeLayoutStage(on graph: CanvasGraph) -> CanvasGraph {
        // Safe mode: legacy handlers already applied tree relayout.
        graph
    }

    private func runAreaLayoutStage(on graph: CanvasGraph) -> CanvasGraph {
        // Safe mode: legacy handlers already applied area overlap resolution.
        graph
    }

    private func runFocusNormalizationStage(on graph: CanvasGraph) -> CanvasGraph {
        // Safe mode: legacy handlers already resolved focus transitions.
        graph
    }

    private func runViewportIntentStage(
        graphBeforeMutation: CanvasGraph,
        graphAfterPipeline: CanvasGraph
    ) -> CanvasViewportIntent? {
        guard graphBeforeMutation.focusedNodeID != graphAfterPipeline.focusedNodeID else {
            return nil
        }
        return .resetManualPanOffset
    }

    private func hasAddedNode(from oldGraph: CanvasGraph, to newGraph: CanvasGraph) -> Bool {
        let previousNodeIDs = Set(oldGraph.nodesByID.keys)
        return newGraph.nodesByID.keys.contains { !previousNodeIDs.contains($0) }
    }
}
