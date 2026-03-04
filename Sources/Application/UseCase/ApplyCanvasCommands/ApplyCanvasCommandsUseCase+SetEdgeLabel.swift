// Background: Edge-target inline editing needs a command path that mutates edge labels.
// Responsibility: Update label of an existing edge while preserving all other edge fields.
import Domain

extension ApplyCanvasCommandsUseCase {
    /// Updates one edge label and keeps graph focus/selection untouched.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - edgeID: Target edge identifier.
    ///   - label: Edited label (empty string becomes `nil`).
    /// - Returns: Mutation result with updated edge label, or no-op when unchanged/missing.
    func setEdgeLabel(
        in graph: CanvasGraph,
        edgeID: CanvasEdgeID,
        label: String
    ) -> CanvasMutationResult {
        guard let edge = graph.edgesByID[edgeID] else {
            return noOpMutationResult(for: graph)
        }

        let normalizedLabel = label.isEmpty ? nil : label
        if edge.label == normalizedLabel {
            return noOpMutationResult(for: graph)
        }

        let updatedEdge = CanvasEdge(
            id: edge.id,
            fromNodeID: edge.fromNodeID,
            toNodeID: edge.toNodeID,
            relationType: edge.relationType,
            directionality: edge.directionality,
            parentChildOrder: edge.parentChildOrder,
            label: normalizedLabel,
            metadata: edge.metadata
        )
        var edgesByID = graph.edgesByID
        edgesByID[edgeID] = updatedEdge

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: edgesByID,
            focusedNodeID: graph.focusedNodeID,
            focusedElement: graph.focusedElement,
            selectedNodeIDs: graph.selectedNodeIDs,
            selectedEdgeIDs: graph.selectedEdgeIDs,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: false
            )
        )
    }
}
