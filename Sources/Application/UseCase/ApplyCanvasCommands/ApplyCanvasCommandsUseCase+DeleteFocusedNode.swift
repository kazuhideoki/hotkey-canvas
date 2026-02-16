import Domain

// Background: Focus behavior after node deletion needs deterministic hierarchy-aware priority.
// Responsibility: Delete the focused subtree and choose next focus by upper-sibling, parent, then nearest node.
extension ApplyCanvasCommandsUseCase {
    func deleteFocusedNode(in graph: CanvasGraph) throws -> CanvasGraph {
        guard let focusedNodeID = graph.focusedNodeID else {
            return graph
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return graph
        }

        var graphAfterDelete = graph
        let subtreeNodeIDs = descendantNodeIDs(of: focusedNodeID, in: graph)
            .union([focusedNodeID])
            .sorted { $0.rawValue < $1.rawValue }

        for nodeID in subtreeNodeIDs {
            graphAfterDelete = try CanvasGraphCRUDService.deleteNode(id: nodeID, in: graphAfterDelete)
        }
        let graphAfterTreeLayout = relayoutParentChildTrees(in: graphAfterDelete)
        let nextFocusNodeID = nextFocusedNodeIDAfterDeletion(
            deleting: focusedNodeID,
            focusedNode: focusedNode,
            in: graph,
            graphAfterDelete: graphAfterTreeLayout
        )
        let graphAfterAreaLayout =
            if let nextFocusNodeID {
                resolveAreaOverlaps(around: nextFocusNodeID, in: graphAfterTreeLayout)
            } else {
                graphAfterTreeLayout
            }

        return CanvasGraph(
            nodesByID: graphAfterAreaLayout.nodesByID,
            edgesByID: graphAfterAreaLayout.edgesByID,
            focusedNodeID: nextFocusNodeID
        )
    }

    private func nextFocusedNodeIDAfterDeletion(
        deleting focusedNodeID: CanvasNodeID,
        focusedNode: CanvasNode,
        in graphBeforeDelete: CanvasGraph,
        graphAfterDelete: CanvasGraph
    ) -> CanvasNodeID? {
        if let upperSiblingID = upperSiblingNodeID(of: focusedNodeID, in: graphBeforeDelete),
            graphAfterDelete.nodesByID[upperSiblingID] != nil
        {
            return upperSiblingID
        }

        if let parentID = parentNodeID(of: focusedNodeID, in: graphBeforeDelete),
            graphAfterDelete.nodesByID[parentID] != nil
        {
            return parentID
        }

        return nearestNodeID(to: focusedNode, in: graphAfterDelete)
    }

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

    private func upperSiblingNodeID(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasNodeID? {
        guard let parentID = parentNodeID(of: nodeID, in: graph) else {
            return nil
        }
        guard let targetNode = graph.nodesByID[nodeID] else {
            return nil
        }

        let siblingNodes = graph.edgesByID.values
            .filter {
                $0.relationType == .parentChild
                    && $0.fromNodeID == parentID
                    && $0.toNodeID != nodeID
            }
            .compactMap { graph.nodesByID[$0.toNodeID] }
            .sorted(by: isNodeOrderedBefore)

        return siblingNodes.last(where: { isNodeOrderedBefore($0, targetNode) })?.id
    }

    private func isNodeOrderedBefore(_ lhs: CanvasNode, _ rhs: CanvasNode) -> Bool {
        if lhs.bounds.y != rhs.bounds.y {
            return lhs.bounds.y < rhs.bounds.y
        }
        if lhs.bounds.x != rhs.bounds.x {
            return lhs.bounds.x < rhs.bounds.x
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }
}
