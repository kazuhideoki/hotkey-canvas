import Domain

// Background: Focus behavior after node deletion needs deterministic hierarchy-aware priority.
// Responsibility: Delete the focused subtree and choose next focus by sibling, parent, then nearest node.
extension ApplyCanvasCommandsUseCase {
    /// Deletes the focused subtree and chooses deterministic next focus before pipeline recomputation.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Mutation result with deletion effects and optional area-layout seed.
    /// - Throws: Propagates node deletion failures from CRUD service.
    func deleteFocusedNode(in graph: CanvasGraph) throws -> CanvasMutationResult {
        guard let focusedNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return noOpMutationResult(for: graph)
        }

        var graphAfterDelete = graph
        let subtreeNodeIDs = descendantNodeIDs(of: focusedNodeID, in: graph)
            .union([focusedNodeID])
            .sorted { $0.rawValue < $1.rawValue }

        for nodeID in subtreeNodeIDs {
            graphAfterDelete = try CanvasGraphCRUDService.deleteNode(id: nodeID, in: graphAfterDelete).get()
        }
        graphAfterDelete = CanvasAreaMembershipService.remove(
            nodeIDs: Set(subtreeNodeIDs),
            in: graphAfterDelete
        )
        let graphAfterTreeLayoutPreview = relayoutParentChildTrees(in: graphAfterDelete)
        let nextFocusNodeID = nextFocusedNodeIDAfterDeletion(
            deleting: focusedNodeID,
            focusedNode: focusedNode,
            in: graph,
            graphAfterDelete: graphAfterTreeLayoutPreview
        )

        let nextGraph = CanvasGraph(
            nodesByID: graphAfterDelete.nodesByID,
            edgesByID: graphAfterDelete.edgesByID,
            focusedNodeID: nextFocusNodeID,
            collapsedRootNodeIDs: CanvasFoldedSubtreeVisibilityService.normalizedCollapsedRootNodeIDs(
                in: graphAfterDelete
            ),
            areasByID: graphAfterDelete.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: nextFocusNodeID != nil,
                needsFocusNormalization: true
            ),
            areaLayoutSeedNodeID: nextFocusNodeID
        )
    }

    /// Picks next focus by sibling, then parent, then geometric nearest node fallback.
    private func nextFocusedNodeIDAfterDeletion(
        deleting focusedNodeID: CanvasNodeID,
        focusedNode: CanvasNode,
        in graphBeforeDelete: CanvasGraph,
        graphAfterDelete: CanvasGraph
    ) -> CanvasNodeID? {
        if let siblingID = siblingNodeID(
            of: focusedNodeID,
            in: graphBeforeDelete,
            excluding: graphAfterDelete
        ) {
            return siblingID
        }

        if let parentID = parentNodeID(of: focusedNodeID, in: graphBeforeDelete),
            graphAfterDelete.nodesByID[parentID] != nil
        {
            return parentID
        }

        return nearestNodeID(to: focusedNode, in: graphAfterDelete)
    }

    /// Finds nearest node center to preserve editing continuity after deletion.
    private func nearestNodeID(to sourceNode: CanvasNode, in graph: CanvasGraph) -> CanvasNodeID? {
        let sourceCenter = nodeCenter(for: sourceNode)
        return graph.nodesByID.values.min { lhs, rhs in
            let lhsDistance = squaredDistance(from: sourceCenter, to: nodeCenter(for: lhs))
            let rhsDistance = squaredDistance(from: sourceCenter, to: nodeCenter(for: rhs))
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            if lhs.bounds.y != rhs.bounds.y {
                return lhs.bounds.y < rhs.bounds.y
            }
            if lhs.bounds.x != rhs.bounds.x {
                return lhs.bounds.x < rhs.bounds.x
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }?.id
    }

    /// Selects a surviving sibling under the same parent using deterministic distance and tie-break ordering.
    private func siblingNodeID(
        of nodeID: CanvasNodeID,
        in graph: CanvasGraph,
        excluding graphAfterDelete: CanvasGraph
    ) -> CanvasNodeID? {
        guard let parentID = parentNodeID(of: nodeID, in: graph) else {
            return nil
        }
        guard let targetNode = graph.nodesByID[nodeID] else {
            return nil
        }
        let targetCenter = nodeCenter(for: targetNode)

        let siblingNodes = graph.edgesByID.values
            .filter {
                $0.relationType == .parentChild
                    && $0.fromNodeID == parentID
                    && $0.toNodeID != nodeID
            }
            .compactMap { graph.nodesByID[$0.toNodeID] }
            .filter { graphAfterDelete.nodesByID[$0.id] != nil }

        return siblingNodes.min { lhs, rhs in
            let lhsDistance = squaredDistance(from: targetCenter, to: nodeCenter(for: lhs))
            let rhsDistance = squaredDistance(from: targetCenter, to: nodeCenter(for: rhs))
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            if lhs.bounds.y != rhs.bounds.y {
                return lhs.bounds.y < rhs.bounds.y
            }
            if lhs.bounds.x != rhs.bounds.x {
                return lhs.bounds.x < rhs.bounds.x
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }?.id
    }

}
