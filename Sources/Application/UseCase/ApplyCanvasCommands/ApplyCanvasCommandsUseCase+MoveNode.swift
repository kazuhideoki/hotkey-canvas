import Domain

// Background: Keyboard-first editing needs direct structure changes without creating or deleting nodes.
// Responsibility: Move the focused node across sibling order and nesting levels.
extension ApplyCanvasCommandsUseCase {
    /// Moves the focused node according to nesting-aware direction semantics.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - direction: Move direction bound to command-arrow shortcuts.
    ///   - areaMode: Editing mode of focused area.
    /// - Returns: Updated graph, or the original graph when movement is not applicable.
    /// - Throws: Propagates graph mutation errors from edge updates.
    func moveNode(
        in graph: CanvasGraph,
        direction: CanvasNodeMoveDirection,
        areaMode: CanvasEditingMode
    ) throws -> CanvasMutationResult {
        guard
            let focusedNodeID = graph.focusedNodeID,
            graph.nodesByID[focusedNodeID] != nil
        else {
            return noOpMutationResult(for: graph)
        }
        let targetNodeIDs = moveTargetNodeIDs(in: graph, focusedNodeID: focusedNodeID)

        if areaMode == .diagram {
            return moveNodeByDirectionSlot(
                in: graph,
                focusedNodeID: focusedNodeID,
                targetNodeIDs: targetNodeIDs,
                direction: direction
            )
        }

        let graphAfterMutation: CanvasGraph
        if targetNodeIDs.count > 1 {
            graphAfterMutation = try moveTreeNodesAsSiblings(
                in: graph,
                focusedNodeID: focusedNodeID,
                targetNodeIDs: targetNodeIDs,
                direction: direction
            )
        } else {
            graphAfterMutation = try moveSingleTreeNode(
                in: graph,
                focusedNodeID: focusedNodeID,
                direction: direction
            )
        }

        guard graphAfterMutation != graph else {
            return noOpMutationResult(for: graph)
        }
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: graphAfterMutation,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: graphAfterMutation.focusedNodeID
        )
    }

    /// Nudges the focused node by a fixed pixel amount in diagram mode.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - direction: Nudge direction.
    ///   - areaMode: Editing mode of focused area.
    /// - Returns: Updated graph when movement is applicable.
    func nudgeNode(
        in graph: CanvasGraph,
        direction: CanvasNodeMoveDirection,
        areaMode: CanvasEditingMode
    ) -> CanvasMutationResult {
        guard areaMode == .diagram else {
            return noOpMutationResult(for: graph)
        }
        guard
            let focusedNodeID = graph.focusedNodeID,
            graph.nodesByID[focusedNodeID] != nil
        else {
            return noOpMutationResult(for: graph)
        }
        let targetNodeIDs = moveTargetNodeIDs(in: graph, focusedNodeID: focusedNodeID)
        return nudgeNodeByDirectionSlot(
            in: graph,
            focusedNodeID: focusedNodeID,
            targetNodeIDs: targetNodeIDs,
            direction: direction
        )
    }
}

extension ApplyCanvasCommandsUseCase {
    private func moveTargetNodeIDs(
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID
    ) -> [CanvasNodeID] {
        let focusedAreaID: CanvasAreaID
        switch CanvasAreaMembershipService.areaID(containing: focusedNodeID, in: graph) {
        case .success(let areaID):
            focusedAreaID = areaID
        case .failure:
            return [focusedNodeID]
        }

        let selectedNodeIDsInArea = graph.selectedNodeIDs.filter { selectedNodeID in
            guard graph.nodesByID[selectedNodeID] != nil else {
                return false
            }
            switch CanvasAreaMembershipService.areaID(containing: selectedNodeID, in: graph) {
            case .success(let selectedAreaID):
                return selectedAreaID == focusedAreaID
            case .failure:
                return false
            }
        }
        guard selectedNodeIDsInArea.contains(focusedNodeID), selectedNodeIDsInArea.count > 1 else {
            return [focusedNodeID]
        }

        return selectedNodeIDsInArea.sorted(by: { lhs, rhs in
            guard
                let lhsNode = graph.nodesByID[lhs],
                let rhsNode = graph.nodesByID[rhs]
            else {
                return lhs.rawValue < rhs.rawValue
            }
            return isPeerNodeOrderedBefore(lhsNode, rhsNode)
        })
    }

    private func moveSingleTreeNode(
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID,
        direction: CanvasNodeMoveDirection
    ) throws -> CanvasGraph {
        let focusedGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: focusedNodeID,
            selectedNodeIDs: graph.selectedNodeIDs,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
        switch direction {
        case .up:
            return try moveNodeVertically(in: focusedGraph, offset: -1)
        case .down:
            return try moveNodeVertically(in: focusedGraph, offset: 1)
        case .left:
            return try outdentNode(in: focusedGraph)
        case .right:
            return try indentNode(in: focusedGraph)
        case .upLeft, .upRight, .downLeft, .downRight:
            return graph
        }
    }

    private func moveTreeNodesAsSiblings(
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID,
        targetNodeIDs: [CanvasNodeID],
        direction: CanvasNodeMoveDirection
    ) throws -> CanvasGraph {
        let targetNodeIDSet = Set(targetNodeIDs)
        let focusedMovedGraph: CanvasGraph
        switch direction {
        case .up:
            focusedMovedGraph = try moveNodeVerticallyInMultiSelection(
                in: graph,
                focusedNodeID: focusedNodeID,
                offset: -1,
                targetNodeIDs: targetNodeIDSet
            )
        case .down:
            focusedMovedGraph = try moveNodeVerticallyInMultiSelection(
                in: graph,
                focusedNodeID: focusedNodeID,
                offset: 1,
                targetNodeIDs: targetNodeIDSet
            )
        case .left, .right, .upLeft, .upRight, .downLeft, .downRight:
            focusedMovedGraph = try moveSingleTreeNode(
                in: graph,
                focusedNodeID: focusedNodeID,
                direction: direction
            )
        }
        guard focusedMovedGraph != graph else {
            return graph
        }
        guard let movedFocusedNode = focusedMovedGraph.nodesByID[focusedNodeID] else {
            return graph
        }

        let destinationParentNodeID = resolvedTreeDestinationParentNodeID(
            of: focusedNodeID,
            in: focusedMovedGraph,
            excluding: targetNodeIDSet
        )

        let nextEdgesByID = rewiredTreeEdgesForSiblingMove(
            from: focusedMovedGraph.edgesByID,
            focusedNodeID: focusedNodeID,
            nodesByID: focusedMovedGraph.nodesByID,
            targetNodeIDs: targetNodeIDs,
            destinationParentNodeID: destinationParentNodeID
        )
        guard let focusedIndex = targetNodeIDs.firstIndex(of: focusedNodeID) else {
            return graph
        }
        let nodeOverrides = movedTreeNodesAsSiblings(
            from: focusedMovedGraph.nodesByID,
            targetNodeIDs: targetNodeIDs,
            focusedIndex: focusedIndex,
            focusedBounds: movedFocusedNode.bounds
        )

        return CanvasGraph(
            nodesByID: focusedMovedGraph.nodesByID.merging(nodeOverrides, uniquingKeysWith: { _, new in new }),
            edgesByID: nextEdgesByID,
            focusedNodeID: focusedMovedGraph.focusedNodeID,
            selectedNodeIDs: graph.selectedNodeIDs,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }

    private func moveNodeVertically(in graph: CanvasGraph, offset: Int) throws -> CanvasGraph {
        guard let focusedNodeID = graph.focusedNodeID else {
            return graph
        }
        let peers = orderedPeerNodes(of: focusedNodeID, in: graph)
        guard let focusedIndex = peers.firstIndex(where: { $0.id == focusedNodeID }) else {
            return graph
        }
        let destinationIndex = focusedIndex + offset
        guard peers.indices.contains(destinationIndex) else {
            return graph
        }
        let destinationNode = peers[destinationIndex]
        return moveNodeVertically(
            in: graph,
            focusedNodeID: focusedNodeID,
            destinationNodeID: destinationNode.id
        )
    }

    func moveNodeVertically(
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID,
        destinationNodeID: CanvasNodeID
    ) -> CanvasGraph {
        guard
            let focusedNode = graph.nodesByID[focusedNodeID],
            let destination = graph.nodesByID[destinationNodeID]
        else {
            return graph
        }
        if let parentID = parentNodeID(of: focusedNodeID, in: graph),
            let nextGraph = swapSiblingOrder(
                parentID: parentID,
                focusedNodeID: focusedNodeID,
                destinationNodeID: destinationNodeID,
                in: graph
            )
        {
            return nextGraph
        }

        return swapPeerBounds(
            focusedNodeID: focusedNodeID,
            focusedNode: focusedNode,
            destinationNode: destination,
            graph: graph
        )
    }

    private func swapSiblingOrder(
        parentID: CanvasNodeID,
        focusedNodeID: CanvasNodeID,
        destinationNodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> CanvasGraph? {
        let normalizedGraph = normalizeParentChildOrder(for: parentID, in: graph)
        let siblingEdges = parentChildEdges(of: parentID, in: normalizedGraph)
        guard
            let focusedEdge = siblingEdges.first(where: { $0.toNodeID == focusedNodeID }),
            let destinationEdge = siblingEdges.first(where: { $0.toNodeID == destinationNodeID }),
            let focusedOrder = focusedEdge.parentChildOrder,
            let destinationOrder = destinationEdge.parentChildOrder
        else {
            return nil
        }

        var edgesByID = normalizedGraph.edgesByID
        edgesByID[focusedEdge.id] = edgeByReplacingParentChildOrder(
            edge: focusedEdge,
            parentChildOrder: destinationOrder
        )
        edgesByID[destinationEdge.id] = edgeByReplacingParentChildOrder(
            edge: destinationEdge,
            parentChildOrder: focusedOrder
        )
        return CanvasGraph(
            nodesByID: normalizedGraph.nodesByID,
            edgesByID: edgesByID,
            focusedNodeID: normalizedGraph.focusedNodeID,
            selectedNodeIDs: normalizedGraph.selectedNodeIDs,
            collapsedRootNodeIDs: normalizedGraph.collapsedRootNodeIDs,
            areasByID: normalizedGraph.areasByID
        )
    }

    private func swapPeerBounds(
        focusedNodeID: CanvasNodeID,
        focusedNode: CanvasNode,
        destinationNode: CanvasNode,
        graph: CanvasGraph
    ) -> CanvasGraph {
        let focusedWithMovedBounds = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            attachments: focusedNode.attachments,
            bounds: CanvasBounds(
                x: destinationNode.bounds.x,
                y: destinationNode.bounds.y,
                width: focusedNode.bounds.width,
                height: focusedNode.bounds.height
            ),
            metadata: focusedNode.metadata,
            markdownStyleEnabled: focusedNode.markdownStyleEnabled
        )
        let destinationWithMovedBounds = CanvasNode(
            id: destinationNode.id,
            kind: destinationNode.kind,
            text: destinationNode.text,
            attachments: destinationNode.attachments,
            bounds: CanvasBounds(
                x: focusedNode.bounds.x,
                y: focusedNode.bounds.y,
                width: destinationNode.bounds.width,
                height: destinationNode.bounds.height
            ),
            metadata: destinationNode.metadata,
            markdownStyleEnabled: destinationNode.markdownStyleEnabled
        )
        return CanvasGraph(
            nodesByID: graph.nodesByID.merging(
                [
                    focusedNodeID: focusedWithMovedBounds,
                    destinationNode.id: destinationWithMovedBounds,
                ],
                uniquingKeysWith: { _, new in new }
            ),
            edgesByID: graph.edgesByID,
            focusedNodeID: focusedNodeID,
            selectedNodeIDs: graph.selectedNodeIDs,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }

}
