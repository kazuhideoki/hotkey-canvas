import Domain

// Background: Edge-target editing requires a deterministic way to cycle arrow direction on the focused edge.
// Responsibility: Update focused edge directionality while keeping existing focus/selection state.
extension ApplyCanvasCommandsUseCase {
    /// Cycles focused edge directionality in `none -> fromTo -> toFrom -> none` order.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - focusedEdge: Focus payload used to resolve target edge and origin node.
    /// - Returns: Mutation result with updated edge directionality when focused edge exists.
    func cycleFocusedEdgeDirectionality(
        in graph: CanvasGraph,
        focusedEdge: CanvasEdgeFocus,
        selectedEdgeIDs: Set<CanvasEdgeID>
    ) -> CanvasMutationResult {
        guard let edge = graph.edgesByID[focusedEdge.edgeID] else {
            return noOpMutationResult(for: graph)
        }

        let updatedEdge = CanvasEdge(
            id: edge.id,
            fromNodeID: edge.fromNodeID,
            toNodeID: edge.toNodeID,
            relationType: edge.relationType,
            directionality: nextDirectionality(from: edge.directionality),
            parentChildOrder: edge.parentChildOrder,
            label: edge.label,
            metadata: edge.metadata
        )
        var edgesByID = graph.edgesByID
        edgesByID[updatedEdge.id] = updatedEdge

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: edgesByID,
            focusedNodeID: graph.focusedNodeID,
            focusedElement: .edge(focusedEdge),
            selectedNodeIDs: graph.selectedNodeIDs,
            selectedEdgeIDs: CanvasSelectionService.normalizedSelectedEdgeIDs(
                from: selectedEdgeIDs,
                in: graph,
                focusedEdgeID: focusedEdge.edgeID
            ),
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

    /// Returns next directionality state for one cycle step.
    private func nextDirectionality(from directionality: CanvasEdgeDirectionality) -> CanvasEdgeDirectionality {
        switch directionality {
        case .none:
            return .fromTo
        case .fromTo:
            return .toFrom
        case .toFrom:
            return .none
        default:
            return .none
        }
    }
}
