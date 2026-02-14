import Domain

// Background: Focus behavior after node deletion needs deterministic hierarchy-aware priority.
// Responsibility: Delete the focused subtree and choose the next focused node by sibling/parent/nearest order.
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
        let nextFocusedNodeID = nextFocusedNodeIDAfterDeletion(
            deleting: focusedNodeID,
            focusedNode: focusedNode,
            in: graph,
            graphAfterDelete: graphAfterDelete
        )

        return CanvasGraph(
            nodesByID: graphAfterDelete.nodesByID,
            edgesByID: graphAfterDelete.edgesByID,
            focusedNodeID: nextFocusedNodeID
        )
    }

    private func nextFocusedNodeIDAfterDeletion(
        deleting focusedNodeID: CanvasNodeID,
        focusedNode: CanvasNode,
        in graphBeforeDelete: CanvasGraph,
        graphAfterDelete: CanvasGraph
    ) -> CanvasNodeID? {
        if let upperSiblingID = upperSiblingNodeID(of: focusedNodeID, in: graphBeforeDelete),
            graphAfterDelete.nodesByID[upperSiblingID] != nil {
            return upperSiblingID
        }

        if let parentID = parentNodeID(of: focusedNodeID, in: graphBeforeDelete),
            graphAfterDelete.nodesByID[parentID] != nil {
            return parentID
        }

        return nearestNodeID(to: focusedNode, in: graphAfterDelete)
    }

    private func nearestNodeID(to sourceNode: CanvasNode, in graph: CanvasGraph) -> CanvasNodeID? {
        let sourceCenter = nodeCenter(sourceNode)
        return graph.nodesByID.values.min { lhs, rhs in
            let lhsDistance = squaredDistance(from: sourceCenter, to: nodeCenter(lhs))
            let rhsDistance = squaredDistance(from: sourceCenter, to: nodeCenter(rhs))
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

    private func nodeCenter(_ node: CanvasNode) -> (x: Double, y: Double) {
        (
            x: node.bounds.x + (node.bounds.width / 2),
            y: node.bounds.y + (node.bounds.height / 2)
        )
    }

    private func squaredDistance(
        from source: (x: Double, y: Double),
        to destination: (x: Double, y: Double)
    ) -> Double {
        let deltaX = destination.x - source.x
        let deltaY = destination.y - source.y
        return (deltaX * deltaX) + (deltaY * deltaY)
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

    private func parentNodeID(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasNodeID? {
        graph.edgesByID.values
            .filter {
                $0.relationType == .parentChild && $0.toNodeID == nodeID
            }
            .sorted(by: isEdgeOrderedBefore)
            .first?
            .fromNodeID
    }

    private func isEdgeOrderedBefore(_ lhs: CanvasEdge, _ rhs: CanvasEdge) -> Bool {
        if lhs.id.rawValue != rhs.id.rawValue {
            return lhs.id.rawValue < rhs.id.rawValue
        }
        if lhs.fromNodeID.rawValue != rhs.fromNodeID.rawValue {
            return lhs.fromNodeID.rawValue < rhs.fromNodeID.rawValue
        }
        if lhs.toNodeID.rawValue != rhs.toNodeID.rawValue {
            return lhs.toNodeID.rawValue < rhs.toNodeID.rawValue
        }
        if lhs.relationType.rawValue != rhs.relationType.rawValue {
            return lhs.relationType.rawValue < rhs.relationType.rawValue
        }
        return false
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

    private func descendantNodeIDs(of rootID: CanvasNodeID, in graph: CanvasGraph) -> Set<CanvasNodeID> {
        var visited: Set<CanvasNodeID> = []
        var queue: [CanvasNodeID] = [rootID]

        while !queue.isEmpty {
            let currentID = queue.removeFirst()
            for edge in graph.edgesByID.values
            where edge.relationType == .parentChild && edge.fromNodeID == currentID {
                let childID = edge.toNodeID
                guard !visited.contains(childID) else {
                    continue
                }
                visited.insert(childID)
                queue.append(childID)
            }
        }

        return visited
    }
}
