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
        guard let seedArea = focusedArea(containing: seedNodeID, in: graph) else {
            return graph
        }

        switch seedArea.editingMode {
        case .tree:
            return runTreeAreaLayoutStage(on: graph, seedNodeID: seedNodeID)
        case .diagram:
            let graphAfterNodeLayout = runDiagramNodeLayoutStage(
                on: graph,
                seedNodeID: seedNodeID,
                in: seedArea
            )
            return runDiagramAreaLayoutStage(
                on: graphAfterNodeLayout,
                seedAreaID: seedArea.id
            )
        }
    }

    private func focusedArea(containing seedNodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasArea? {
        graph.areasByID.values
            .filter { $0.nodeIDs.contains(seedNodeID) }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first
    }

    private func runTreeAreaLayoutStage(on graph: CanvasGraph, seedNodeID: CanvasNodeID) -> CanvasGraph {
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
        return applyingAreaTranslations(
            to: graph,
            areas: areas,
            translationsByAreaID: translationsByAreaID
        )
    }

    private func runDiagramNodeLayoutStage(
        on graph: CanvasGraph,
        seedNodeID: CanvasNodeID,
        in seedArea: CanvasArea
    ) -> CanvasGraph {
        let nodeIDs = seedArea.nodeIDs
            .filter { graph.nodesByID[$0] != nil }
            .sorted { $0.rawValue < $1.rawValue }
        guard nodeIDs.count > 1 else {
            return graph
        }

        let areas: [CanvasNodeArea] = nodeIDs.map { nodeID in
            guard let node = graph.nodesByID[nodeID] else {
                preconditionFailure("Node ID listed in area must exist in graph: \(nodeID.rawValue)")
            }
            let bounds = CanvasRect(
                minX: node.bounds.x,
                minY: node.bounds.y,
                width: node.bounds.width,
                height: node.bounds.height
            )
            return CanvasNodeArea(
                id: nodeID,
                nodeIDs: [nodeID],
                bounds: bounds,
                shape: .rectangle
            )
        }

        let translationsByAreaID = CanvasAreaLayoutService.resolveOverlaps(
            areas: areas,
            seedAreaID: seedNodeID,
            minimumSpacing: 16
        )
        return applyingAreaTranslations(
            to: graph,
            areas: areas,
            translationsByAreaID: translationsByAreaID
        )
    }

    private func runDiagramAreaLayoutStage(on graph: CanvasGraph, seedAreaID: CanvasAreaID) -> CanvasGraph {
        let sortedAreas = graph.areasByID.values.sorted { $0.id.rawValue < $1.id.rawValue }
        let layoutAreas = sortedAreas.compactMap { area in
            areaNodeLayoutArea(area: area, in: graph)
        }
        guard layoutAreas.count > 1 else {
            return graph
        }

        let seedLayoutAreaID = CanvasNodeID(rawValue: "area-\(seedAreaID.rawValue)")
        let translationsByAreaID = CanvasAreaLayoutService.resolveOverlaps(
            areas: layoutAreas,
            seedAreaID: seedLayoutAreaID,
            minimumSpacing: 32
        )
        return applyingAreaTranslations(
            to: graph,
            areas: layoutAreas,
            translationsByAreaID: translationsByAreaID
        )
    }

    private func areaNodeLayoutArea(area: CanvasArea, in graph: CanvasGraph) -> CanvasNodeArea? {
        let nodes = area.nodeIDs.compactMap { graph.nodesByID[$0] }
        guard let firstNode = nodes.first else {
            return nil
        }

        var minX = firstNode.bounds.x
        var minY = firstNode.bounds.y
        var maxX = firstNode.bounds.x + firstNode.bounds.width
        var maxY = firstNode.bounds.y + firstNode.bounds.height

        for node in nodes {
            minX = min(minX, node.bounds.x)
            minY = min(minY, node.bounds.y)
            maxX = max(maxX, node.bounds.x + node.bounds.width)
            maxY = max(maxY, node.bounds.y + node.bounds.height)
        }

        let bounds = CanvasRect(
            minX: minX,
            minY: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        return CanvasNodeArea(
            id: CanvasNodeID(rawValue: "area-\(area.id.rawValue)"),
            nodeIDs: area.nodeIDs,
            bounds: bounds,
            shape: .rectangle
        )
    }

    private func applyingAreaTranslations(
        to graph: CanvasGraph,
        areas: [CanvasNodeArea],
        translationsByAreaID: [CanvasNodeID: CanvasTranslation]
    ) -> CanvasGraph {
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
