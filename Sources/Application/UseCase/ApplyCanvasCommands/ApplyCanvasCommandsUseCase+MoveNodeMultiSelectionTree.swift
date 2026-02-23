import Domain

// Background: Multi-selection move in tree mode rewires parent-child relations and repositions selected nodes.
// Responsibility: Host helper routines used by tree multi-selection move operations.
extension ApplyCanvasCommandsUseCase {
    private static let treeMultiSelectionOrderingEpsilon: Double = 0.001

    func rewiredTreeEdgesForSiblingMove(
        from originalEdgesByID: [CanvasEdgeID: CanvasEdge],
        targetNodeIDs: [CanvasNodeID],
        destinationParentNodeID: CanvasNodeID?
    ) -> [CanvasEdgeID: CanvasEdge] {
        let targetNodeIDSet = Set(targetNodeIDs)
        var nextEdgesByID = originalEdgesByID.filter { _, edge in
            if edge.relationType != .parentChild {
                return true
            }
            if targetNodeIDSet.contains(edge.toNodeID) {
                return false
            }
            if targetNodeIDSet.contains(edge.fromNodeID) && targetNodeIDSet.contains(edge.toNodeID) {
                return false
            }
            return true
        }
        if let destinationParentNodeID {
            for nodeID in targetNodeIDs where nodeID != destinationParentNodeID {
                let edge = makeParentChildEdge(from: destinationParentNodeID, to: nodeID)
                nextEdgesByID[edge.id] = edge
            }
        }
        return nextEdgesByID
    }

    func movedTreeNodesAsSiblings(
        from originalNodesByID: [CanvasNodeID: CanvasNode],
        targetNodeIDs: [CanvasNodeID],
        focusedIndex: Int,
        focusedBounds: CanvasBounds
    ) -> [CanvasNodeID: CanvasNode] {
        var nodeOverrides: [CanvasNodeID: CanvasNode] = [:]
        for (index, nodeID) in targetNodeIDs.enumerated() {
            guard let node = originalNodesByID[nodeID] else {
                continue
            }
            let nextY = focusedBounds.y + (Double(index - focusedIndex) * Self.treeMultiSelectionOrderingEpsilon)
            nodeOverrides[nodeID] = CanvasNode(
                id: node.id,
                kind: node.kind,
                text: node.text,
                attachments: node.attachments,
                bounds: CanvasBounds(
                    x: focusedBounds.x,
                    y: nextY,
                    width: node.bounds.width,
                    height: node.bounds.height
                ),
                metadata: node.metadata,
                markdownStyleEnabled: node.markdownStyleEnabled
            )
        }
        return nodeOverrides
    }

    func resolvedTreeDestinationParentNodeID(
        of focusedNodeID: CanvasNodeID,
        in graph: CanvasGraph,
        excluding excludedNodeIDs: Set<CanvasNodeID>
    ) -> CanvasNodeID? {
        var candidateParentNodeID = parentNodeID(of: focusedNodeID, in: graph)
        while let unwrappedParentNodeID = candidateParentNodeID,
            excludedNodeIDs.contains(unwrappedParentNodeID)
        {
            candidateParentNodeID = parentNodeID(of: unwrappedParentNodeID, in: graph)
        }
        return candidateParentNodeID
    }
}
