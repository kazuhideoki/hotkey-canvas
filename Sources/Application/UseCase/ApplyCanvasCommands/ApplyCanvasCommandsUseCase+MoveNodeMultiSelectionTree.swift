import Domain

// Background: Multi-selection move in tree mode rewires parent-child relations and repositions selected nodes.
// Responsibility: Host helper routines used by tree multi-selection move operations.
extension ApplyCanvasCommandsUseCase {
    private static let treeMultiSelectionOrderingEpsilon: Double = 0.001

    func rewiredTreeEdgesForSiblingMove(
        from originalEdgesByID: [CanvasEdgeID: CanvasEdge],
        focusedNodeID: CanvasNodeID,
        nodesByID: [CanvasNodeID: CanvasNode],
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
            let graphBeforeInsertion = CanvasGraph(
                nodesByID: nodesByID,
                edgesByID: nextEdgesByID,
                focusedNodeID: nil,
                selectedNodeIDs: []
            )
            let orderedDestinationChildNodeIDs = parentChildEdges(
                of: destinationParentNodeID,
                in: graphBeforeInsertion
            )
            .map(\.toNodeID)
            let insertionTargetNodeIDs = targetNodeIDs.filter { $0 != destinationParentNodeID }
            let reorderedDestinationChildNodeIDs = reorderedDestinationChildNodeIDs(
                from: orderedDestinationChildNodeIDs,
                insertionTargetNodeIDs: insertionTargetNodeIDs,
                focusedNodeID: focusedNodeID
            )
            rewireDestinationParentChildEdges(
                in: &nextEdgesByID,
                destinationParentNodeID: destinationParentNodeID,
                reorderedDestinationChildNodeIDs: reorderedDestinationChildNodeIDs
            )
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

    private func resolvedInsertionIndex(
        focusedNodeIndexInDestination: Int?,
        orderedDestinationChildNodeIDs: [CanvasNodeID],
        insertionTargetNodeIDSet: Set<CanvasNodeID>
    ) -> Int {
        guard let focusedNodeIndexInDestination else {
            return orderedDestinationChildNodeIDs.count
        }
        let removedCountBeforeFocus = orderedDestinationChildNodeIDs[..<focusedNodeIndexInDestination]
            .filter { insertionTargetNodeIDSet.contains($0) }
            .count
        return focusedNodeIndexInDestination - removedCountBeforeFocus
    }

    private func reorderedDestinationChildNodeIDs(
        from orderedDestinationChildNodeIDs: [CanvasNodeID],
        insertionTargetNodeIDs: [CanvasNodeID],
        focusedNodeID: CanvasNodeID
    ) -> [CanvasNodeID] {
        let insertionTargetNodeIDSet = Set(insertionTargetNodeIDs)
        let focusedNodeIndexInDestination = orderedDestinationChildNodeIDs.firstIndex(of: focusedNodeID)
        let insertionIndex = resolvedInsertionIndex(
            focusedNodeIndexInDestination: focusedNodeIndexInDestination,
            orderedDestinationChildNodeIDs: orderedDestinationChildNodeIDs,
            insertionTargetNodeIDSet: insertionTargetNodeIDSet
        )
        let remainingChildNodeIDs = orderedDestinationChildNodeIDs.filter {
            !insertionTargetNodeIDSet.contains($0)
        }
        let clampedInsertionIndex = max(0, min(insertionIndex, remainingChildNodeIDs.count))
        return Array(remainingChildNodeIDs[..<clampedInsertionIndex])
            + insertionTargetNodeIDs
            + Array(remainingChildNodeIDs[clampedInsertionIndex...])
    }

    private func rewireDestinationParentChildEdges(
        in nextEdgesByID: inout [CanvasEdgeID: CanvasEdge],
        destinationParentNodeID: CanvasNodeID,
        reorderedDestinationChildNodeIDs: [CanvasNodeID]
    ) {
        let existingDestinationEdgesByChildNodeID: [CanvasNodeID: CanvasEdge] = Dictionary(
            uniqueKeysWithValues: nextEdgesByID.values.compactMap { edge in
                guard
                    edge.relationType == .parentChild,
                    edge.fromNodeID == destinationParentNodeID
                else {
                    return nil
                }
                return (edge.toNodeID, edge)
            }
        )
        for (order, childNodeID) in reorderedDestinationChildNodeIDs.enumerated() {
            if let existingEdge = existingDestinationEdgesByChildNodeID[childNodeID] {
                nextEdgesByID[existingEdge.id] = edgeByReplacingParentChildOrder(
                    edge: existingEdge,
                    parentChildOrder: order
                )
            } else {
                let insertedEdge = makeParentChildEdge(
                    from: destinationParentNodeID,
                    to: childNodeID,
                    order: order
                )
                nextEdgesByID[insertedEdge.id] = insertedEdge
            }
        }
    }
}
