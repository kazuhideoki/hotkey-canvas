// Background: Pipeline migration requires a centralized execution order for command mutation and recomputation.
// Responsibility: Execute fixed stage order from mutation outputs and return final pipeline state.
import Domain

/// Coordinator that evaluates fixed pipeline stage order from phase-1 effect contracts.
public struct CanvasCommandPipelineCoordinator: Sendable {
    public init() {}

    /// Runs mutation outputs through the fixed pipeline order and returns the last aggregated result.
    /// - Parameters:
    ///   - baseGraph: Snapshot before executing the current command sequence.
    ///   - mutationResults: Mutation outputs that already classify stage requirements via effects.
    /// - Returns: Final graph and viewport intent after all eligible stages are evaluated.
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
    /// Applies deterministic stage gating from the phase-1 effects contract.
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
            graph = runAreaLayoutStage(
                on: graph,
                seedNodeID: mutationResult.areaLayoutSeedNodeID
            )
        }
        if effects.didMutateGraph {
            graph = runCollapsedRootNormalizationStage(on: graph)
        }
        if effects.didMutateGraph && effects.needsFocusNormalization {
            graph = runFocusNormalizationStage(on: graph)
        }

        return graph
    }

    /// Recomputes parent-child tree bounds when structural mutation requests tree layout.
    private func runTreeLayoutStage(on graph: CanvasGraph) -> CanvasGraph {
        let updatedBoundsByNodeID = CanvasTreeLayoutService.relayoutParentChildTrees(
            in: graph,
            verticalSpacing: 24,
            horizontalSpacing: 32,
            rootSpacing: 48
        )
        guard !updatedBoundsByNodeID.isEmpty else {
            return graph
        }

        var nodesByID = graph.nodesByID
        for nodeID in updatedBoundsByNodeID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let bounds = updatedBoundsByNodeID[nodeID] else {
                continue
            }
            guard let node = nodesByID[nodeID] else {
                continue
            }
            nodesByID[nodeID] = CanvasNode(
                id: node.id,
                kind: node.kind,
                text: node.text,
                bounds: bounds,
                metadata: node.metadata,
                markdownStyleEnabled: node.markdownStyleEnabled
            )
        }

        return CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }

    /// Resolves overlap translations for the connected area that contains the mutation seed node.
    private func runAreaLayoutStage(on graph: CanvasGraph, seedNodeID: CanvasNodeID?) -> CanvasGraph {
        guard let seedNodeID else {
            return graph
        }
        let areas = CanvasAreaLayoutService.makeParentChildAreas(
            in: graph,
            shapeKind: .convexHull
        )
        guard let seedArea = areas.first(where: { $0.nodeIDs.contains(seedNodeID) }) else {
            return graph
        }

        let translationsByAreaID = CanvasAreaLayoutService.resolveOverlaps(
            areas: areas,
            seedAreaID: seedArea.id,
            minimumSpacing: 32
        )
        guard !translationsByAreaID.isEmpty else {
            return graph
        }

        let areasByID = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, $0) })
        var nodesByID = graph.nodesByID

        for areaID in translationsByAreaID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let translation = translationsByAreaID[areaID] else {
                continue
            }
            guard let area = areasByID[areaID] else {
                continue
            }

            for nodeID in area.nodeIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let node = nodesByID[nodeID] else {
                    continue
                }
                nodesByID[nodeID] = CanvasNode(
                    id: node.id,
                    kind: node.kind,
                    text: node.text,
                    bounds: CanvasBounds(
                        x: node.bounds.x + translation.dx,
                        y: node.bounds.y + translation.dy,
                        width: node.bounds.width,
                        height: node.bounds.height
                    ),
                    metadata: node.metadata,
                    markdownStyleEnabled: node.markdownStyleEnabled
                )
            }
        }

        return CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }

    /// Drops collapsed roots that are no longer valid after graph mutation.
    private func runCollapsedRootNormalizationStage(on graph: CanvasGraph) -> CanvasGraph {
        let normalizedCollapsedRootNodeIDs =
            CanvasFoldedSubtreeVisibilityService.normalizedCollapsedRootNodeIDs(in: graph)
        guard normalizedCollapsedRootNodeIDs != graph.collapsedRootNodeIDs else {
            return graph
        }
        return CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            collapsedRootNodeIDs: normalizedCollapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }

    /// Ensures focus points to a visible existing node after mutation and layout.
    private func runFocusNormalizationStage(on graph: CanvasGraph) -> CanvasGraph {
        let normalizedFocusedNodeID = normalizedFocusedNodeID(in: graph)
        guard normalizedFocusedNodeID != graph.focusedNodeID else {
            return graph
        }
        return CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: normalizedFocusedNodeID,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }

    /// Emits viewport intent only when pipeline-level policy defines one.
    private func runViewportIntentStage(
        graphBeforeMutation: CanvasGraph,
        graphAfterPipeline: CanvasGraph
    ) -> CanvasViewportIntent? {
        _ = graphBeforeMutation
        _ = graphAfterPipeline
        return nil
    }

    /// Detects node insertion across the whole sequence for UI behaviors that depend on add operations.
    private func hasAddedNode(from oldGraph: CanvasGraph, to newGraph: CanvasGraph) -> Bool {
        let previousNodeIDs = Set(oldGraph.nodesByID.keys)
        return newGraph.nodesByID.keys.contains { !previousNodeIDs.contains($0) }
    }

    /// Normalizes focus to the first visible node in stable order when current focus is invalid.
    private func normalizedFocusedNodeID(in graph: CanvasGraph) -> CanvasNodeID? {
        let visibleGraph = CanvasFoldedSubtreeVisibilityService.visibleGraph(from: graph)
        guard !visibleGraph.nodesByID.isEmpty else {
            return nil
        }
        if let focusedNodeID = visibleGraph.focusedNodeID, visibleGraph.nodesByID[focusedNodeID] != nil {
            return focusedNodeID
        }
        return visibleGraph.nodesByID.values
            .sorted { lhs, rhs in
                if lhs.bounds.y != rhs.bounds.y {
                    return lhs.bounds.y < rhs.bounds.y
                }
                if lhs.bounds.x != rhs.bounds.x {
                    return lhs.bounds.x < rhs.bounds.x
                }
                return lhs.id.rawValue < rhs.id.rawValue
            }
            .first?
            .id
    }
}
