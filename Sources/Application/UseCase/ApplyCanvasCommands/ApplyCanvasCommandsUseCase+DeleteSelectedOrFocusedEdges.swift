import Domain

// Background: Edge target mode requires a dedicated destructive flow that does not affect nodes.
// Responsibility: Delete focused/selected edges and keep edge focus deterministic when survivors exist.
extension ApplyCanvasCommandsUseCase {
    /// Deletes focused edge or selected edges and resolves next edge focus when possible.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - focusedEdge: Focus payload used as deletion anchor.
    ///   - selectedEdgeIDs: Candidate multi-selection for edge deletion.
    /// - Returns: Mutation result with edge-only deletion effects.
    /// - Throws: Propagates edge deletion failures from CRUD service.
    func deleteSelectedOrFocusedEdges(
        in graph: CanvasGraph,
        focusedEdge: CanvasEdgeFocus,
        selectedEdgeIDs: Set<CanvasEdgeID>
    ) throws -> CanvasMutationResult {
        guard graph.edgesByID[focusedEdge.edgeID] != nil else {
            return noOpMutationResult(for: graph)
        }

        let edgeIDsToDelete = edgeIDsForDeletion(
            focusedEdgeID: focusedEdge.edgeID,
            selectedEdgeIDs: selectedEdgeIDs,
            in: graph
        )
        var graphAfterDelete = graph
        for edgeID in edgeIDsToDelete {
            graphAfterDelete = try CanvasGraphCRUDService.deleteEdge(id: edgeID, in: graphAfterDelete).get()
        }
        let nextGraph = makeGraphAfterEdgeDeletion(
            graphAfterDelete: graphAfterDelete,
            originNodeID: focusedEdge.originNodeID
        )

        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: !edgeIDsToDelete.isEmpty,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: true
            )
        )
    }

    /// Builds post-edge-deletion graph by selecting next edge focus or falling back to node focus.
    private func makeGraphAfterEdgeDeletion(
        graphAfterDelete: CanvasGraph,
        originNodeID: CanvasNodeID
    ) -> CanvasGraph {
        let preferredNextEdgeID = nextFocusedEdgeIDAfterEdgeDeletion(
            originNodeID: originNodeID,
            in: graphAfterDelete
        )
        let nextFocusedNodeID =
            graphAfterDelete.nodesByID[originNodeID] != nil
            ? originNodeID
            : graphAfterDelete.focusedNodeID
        let nextFocusedElement: CanvasFocusedElement? =
            if let preferredNextEdgeID {
                .edge(
                    CanvasEdgeFocus(
                        edgeID: preferredNextEdgeID,
                        originNodeID: resolvedEdgeFocusOriginNodeID(
                            for: preferredNextEdgeID,
                            preferred: originNodeID,
                            in: graphAfterDelete
                        )
                    )
                )
            } else {
                nextFocusedNodeID.map { .node($0) }
            }
        let nextSelectedEdgeIDs: Set<CanvasEdgeID> =
            if let preferredNextEdgeID { [preferredNextEdgeID] } else { [] }

        return CanvasGraph(
            nodesByID: graphAfterDelete.nodesByID,
            edgesByID: graphAfterDelete.edgesByID,
            focusedNodeID: nextFocusedNodeID,
            focusedElement: nextFocusedElement,
            selectedNodeIDs: nextFocusedNodeID.map { [$0] } ?? [],
            selectedEdgeIDs: nextSelectedEdgeIDs,
            collapsedRootNodeIDs: CanvasFoldedSubtreeVisibilityService.normalizedCollapsedRootNodeIDs(
                in: graphAfterDelete
            ),
            areasByID: graphAfterDelete.areasByID
        )
    }

    /// Resolves concrete edge deletion targets from focused edge and optional multi-selection.
    private func edgeIDsForDeletion(
        focusedEdgeID: CanvasEdgeID,
        selectedEdgeIDs: Set<CanvasEdgeID>,
        in graph: CanvasGraph
    ) -> [CanvasEdgeID] {
        let existingSelectedEdgeIDs = selectedEdgeIDs.filter { graph.edgesByID[$0] != nil }
        let shouldDeleteSelection =
            existingSelectedEdgeIDs.contains(focusedEdgeID)
            && existingSelectedEdgeIDs.count > 1
        let edgeIDsToDelete: Set<CanvasEdgeID> = shouldDeleteSelection ? existingSelectedEdgeIDs : [focusedEdgeID]
        return edgeIDsToDelete.sorted { $0.rawValue < $1.rawValue }
    }

    /// Picks the next edge focus candidate deterministically after edge deletion.
    private func nextFocusedEdgeIDAfterEdgeDeletion(
        originNodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> CanvasEdgeID? {
        let orderedEdgeIDs = graph.edgesByID.values
            .sorted { lhs, rhs in
                if lhs.fromNodeID.rawValue != rhs.fromNodeID.rawValue {
                    return lhs.fromNodeID.rawValue < rhs.fromNodeID.rawValue
                }
                if lhs.toNodeID.rawValue != rhs.toNodeID.rawValue {
                    return lhs.toNodeID.rawValue < rhs.toNodeID.rawValue
                }
                return lhs.id.rawValue < rhs.id.rawValue
            }
            .map(\.id)
        if let connectedEdgeID = orderedEdgeIDs.first(where: { edgeID in
            guard let edge = graph.edgesByID[edgeID] else {
                return false
            }
            return edge.fromNodeID == originNodeID || edge.toNodeID == originNodeID
        }) {
            return connectedEdgeID
        }
        return orderedEdgeIDs.first
    }

    /// Selects an edge-focus origin node while preserving previous origin when possible.
    private func resolvedEdgeFocusOriginNodeID(
        for edgeID: CanvasEdgeID,
        preferred preferredOriginNodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> CanvasNodeID {
        guard let edge = graph.edgesByID[edgeID] else {
            return preferredOriginNodeID
        }
        if edge.fromNodeID == preferredOriginNodeID || edge.toNodeID == preferredOriginNodeID {
            return preferredOriginNodeID
        }
        return edge.fromNodeID
    }
}
