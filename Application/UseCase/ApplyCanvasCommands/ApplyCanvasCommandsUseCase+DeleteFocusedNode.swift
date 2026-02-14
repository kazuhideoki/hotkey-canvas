import Domain

// Background: Node deletion must keep graph consistency and update focus deterministically.
// Responsibility: Delete the focused subtree and choose the nearest remaining node as next focus.
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

        return CanvasGraph(
            nodesByID: graphAfterDelete.nodesByID,
            edgesByID: graphAfterDelete.edgesByID,
            focusedNodeID: nearestNodeID(to: focusedNode, in: graphAfterDelete)
        )
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
}
