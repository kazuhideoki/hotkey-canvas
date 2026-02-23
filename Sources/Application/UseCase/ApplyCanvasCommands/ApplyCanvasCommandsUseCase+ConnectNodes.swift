import Domain
import Foundation

// Background: Diagram editing needs an explicit operation to connect already-existing nodes.
// Responsibility: Add one normal edge between source and target nodes selected by UI interaction.
extension ApplyCanvasCommandsUseCase {
    /// Connects two existing nodes with one `normal` edge.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - fromNodeID: Edge source node identifier.
    ///   - toNodeID: Edge destination node identifier.
    /// - Returns: Mutation result with graph update when connection is valid.
    /// - Throws: Propagates CRUD validation errors when creating the edge fails.
    func connectNodes(
        in graph: CanvasGraph,
        fromNodeID: CanvasNodeID,
        toNodeID: CanvasNodeID
    ) throws -> CanvasMutationResult {
        guard fromNodeID != toNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard graph.nodesByID[fromNodeID] != nil, graph.nodesByID[toNodeID] != nil else {
            return noOpMutationResult(for: graph)
        }

        let fromAreaID: CanvasAreaID
        switch CanvasAreaMembershipService.areaID(containing: fromNodeID, in: graph) {
        case .success(let resolvedAreaID):
            fromAreaID = resolvedAreaID
        case .failure:
            return noOpMutationResult(for: graph)
        }
        let toAreaID: CanvasAreaID
        switch CanvasAreaMembershipService.areaID(containing: toNodeID, in: graph) {
        case .success(let resolvedAreaID):
            toAreaID = resolvedAreaID
        case .failure:
            return noOpMutationResult(for: graph)
        }

        guard fromAreaID == toAreaID else {
            return noOpMutationResult(for: graph)
        }
        guard !hasNormalEdge(fromNodeID: fromNodeID, toNodeID: toNodeID, in: graph) else {
            return noOpMutationResult(for: graph)
        }

        let graphAfterMutation = try CanvasGraphCRUDService.createEdge(
            CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-\(UUID().uuidString.lowercased())"),
                fromNodeID: fromNodeID,
                toNodeID: toNodeID,
                relationType: .normal
            ),
            in: graph
        ).get()

        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: graphAfterMutation,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: false
            )
        )
    }
}

extension ApplyCanvasCommandsUseCase {
    /// Returns whether a directed normal edge already exists between source and target.
    /// - Parameters:
    ///   - fromNodeID: Candidate edge source node identifier.
    ///   - toNodeID: Candidate edge destination node identifier.
    ///   - graph: Graph snapshot to inspect.
    /// - Returns: `true` when a matching normal edge already exists.
    private func hasNormalEdge(
        fromNodeID: CanvasNodeID,
        toNodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> Bool {
        graph.edgesByID.values.contains { edge in
            edge.fromNodeID == fromNodeID
                && edge.toNodeID == toNodeID
                && edge.relationType == .normal
        }
    }
}
