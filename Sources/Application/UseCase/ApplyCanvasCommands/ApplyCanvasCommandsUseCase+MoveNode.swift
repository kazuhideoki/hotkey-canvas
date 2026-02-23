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
    private static let orderingEpsilon: Double = 0.001
    private static let indentHorizontalGap: Double = CanvasDefaultNodeDistance.treeHorizontal

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
        let focusedMovedGraph = try moveSingleTreeNode(
            in: graph,
            focusedNodeID: focusedNodeID,
            direction: direction
        )
        guard focusedMovedGraph != graph else {
            return graph
        }
        guard let movedFocusedNode = focusedMovedGraph.nodesByID[focusedNodeID] else {
            return graph
        }

        let targetNodeIDSet = Set(targetNodeIDs)
        let destinationParentNodeID = resolvedTreeDestinationParentNodeID(
            of: focusedNodeID,
            in: focusedMovedGraph,
            excluding: targetNodeIDSet
        )

        let nextEdgesByID = rewiredTreeEdgesForSiblingMove(
            from: graph.edgesByID,
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
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
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
        guard let destination = graph.nodesByID[destinationNode.id] else {
            return graph
        }

        if let parentID = parentNodeID(of: focusedNodeID, in: graph),
            let nextGraph = swapSiblingOrder(
                parentID: parentID,
                focusedNodeID: focusedNodeID,
                destinationNodeID: destination.id,
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

    private func outdentNode(in graph: CanvasGraph) throws -> CanvasGraph {
        guard let focusedNodeID = graph.focusedNodeID else {
            return graph
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return graph
        }
        guard let parentEdge = parentChildIncomingEdge(of: focusedNodeID, in: graph) else {
            return graph
        }
        guard let parentNode = graph.nodesByID[parentEdge.fromNodeID] else {
            return graph
        }
        guard let grandparentNodeID = parentNodeID(of: parentEdge.fromNodeID, in: graph) else {
            return graph
        }
        guard let grandparentNode = graph.nodesByID[grandparentNodeID] else {
            return graph
        }

        guard
            var nextGraph = try outdentedGraph(
                focusedNodeID: focusedNodeID,
                parentNode: parentNode,
                grandparentNode: grandparentNode,
                graph: graph
            )?.0
        else {
            return graph
        }

        let updatedFocusedNode = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            attachments: focusedNode.attachments,
            bounds: CanvasBounds(
                x: parentNode.bounds.x,
                y: parentNode.bounds.y + Self.orderingEpsilon,
                width: focusedNode.bounds.width,
                height: focusedNode.bounds.height
            ),
            metadata: focusedNode.metadata,
            markdownStyleEnabled: focusedNode.markdownStyleEnabled
        )
        nextGraph = CanvasGraph(
            nodesByID: nextGraph.nodesByID.merging(
                [focusedNodeID: updatedFocusedNode], uniquingKeysWith: { _, new in new }),
            edgesByID: nextGraph.edgesByID,
            focusedNodeID: focusedNodeID,
            selectedNodeIDs: nextGraph.selectedNodeIDs,
            collapsedRootNodeIDs: nextGraph.collapsedRootNodeIDs,
            areasByID: nextGraph.areasByID
        )

        return nextGraph
    }

    private func outdentedGraph(
        focusedNodeID: CanvasNodeID,
        parentNode: CanvasNode,
        grandparentNode: CanvasNode,
        graph: CanvasGraph
    ) throws -> (CanvasGraph, Int)? {
        var nextGraph = normalizeParentChildOrder(for: grandparentNode.id, in: graph)
        guard
            let parentAsChildEdge = parentChildEdges(of: grandparentNode.id, in: nextGraph).first(where: {
                $0.toNodeID == parentNode.id
            }),
            let parentOrder = parentAsChildEdge.parentChildOrder
        else {
            return nil
        }
        let insertionOrder = parentOrder + 1
        nextGraph = shiftParentChildOrder(
            for: grandparentNode.id,
            atOrAfter: insertionOrder,
            by: 1,
            in: nextGraph
        )

        guard let latestParentEdge = parentChildIncomingEdge(of: focusedNodeID, in: nextGraph) else {
            return nil
        }
        nextGraph = try CanvasGraphCRUDService.deleteEdge(id: latestParentEdge.id, in: nextGraph).get()
        nextGraph = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(
                from: grandparentNode.id,
                to: focusedNodeID,
                order: insertionOrder
            ),
            in: nextGraph
        ).get()
        return (nextGraph, insertionOrder)
    }

    private func indentNode(in graph: CanvasGraph) throws -> CanvasGraph {
        guard let focusedNodeID = graph.focusedNodeID else {
            return graph
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return graph
        }
        guard !isTopLevelParent(focusedNodeID, in: graph) else {
            return graph
        }

        let peers = orderedPeerNodes(of: focusedNodeID, in: graph)
        guard let focusedIndex = peers.firstIndex(where: { $0.id == focusedNodeID }) else {
            return graph
        }
        let previousIndex = focusedIndex - 1
        guard peers.indices.contains(previousIndex) else {
            return graph
        }
        let newParent = peers[previousIndex]
        let newParentChildren = childNodes(of: newParent.id, in: graph)
        let appendedChildY = appendedChildY(
            under: newParent,
            existingChildren: newParentChildren
        )

        var nextGraph = graph
        if let currentParentEdge = parentChildIncomingEdge(of: focusedNodeID, in: graph) {
            nextGraph = try CanvasGraphCRUDService.deleteEdge(id: currentParentEdge.id, in: nextGraph).get()
        }
        nextGraph = normalizeParentChildOrder(for: newParent.id, in: nextGraph)
        let appendedOrder = nextParentChildOrder(for: newParent.id, in: nextGraph)
        nextGraph = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: newParent.id, to: focusedNodeID, order: appendedOrder),
            in: nextGraph
        ).get()

        let updatedFocusedNode = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            attachments: focusedNode.attachments,
            bounds: CanvasBounds(
                x: newParent.bounds.x + newParent.bounds.width + Self.indentHorizontalGap,
                y: appendedChildY,
                width: focusedNode.bounds.width,
                height: focusedNode.bounds.height
            ),
            metadata: focusedNode.metadata,
            markdownStyleEnabled: focusedNode.markdownStyleEnabled
        )
        nextGraph = CanvasGraph(
            nodesByID: nextGraph.nodesByID.merging(
                [focusedNodeID: updatedFocusedNode], uniquingKeysWith: { _, new in new }),
            edgesByID: nextGraph.edgesByID,
            focusedNodeID: nextGraph.collapsedRootNodeIDs.contains(newParent.id) ? newParent.id : focusedNodeID,
            selectedNodeIDs: nextGraph.selectedNodeIDs,
            collapsedRootNodeIDs: nextGraph.collapsedRootNodeIDs,
            areasByID: nextGraph.areasByID
        )

        return nextGraph
    }

    private func appendedChildY(
        under newParent: CanvasNode,
        existingChildren: [CanvasNode]
    ) -> Double {
        guard !existingChildren.isEmpty else {
            return newParent.bounds.y
        }
        let deepestBottomY =
            existingChildren
            .map { $0.bounds.y + $0.bounds.height }
            .max() ?? newParent.bounds.y
        return deepestBottomY + Self.newNodeVerticalSpacing
    }

    private func orderedPeerNodes(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> [CanvasNode] {
        if let parentID = parentNodeID(of: nodeID, in: graph) {
            return childNodes(of: parentID, in: graph)
        }
        return graph.nodesByID.values
            .filter { isTopLevelParent($0.id, in: graph) }
            .sorted(by: isPeerNodeOrderedBefore)
    }

    private func isPeerNodeOrderedBefore(_ lhs: CanvasNode, _ rhs: CanvasNode) -> Bool {
        if lhs.bounds.y != rhs.bounds.y {
            return lhs.bounds.y < rhs.bounds.y
        }
        if lhs.bounds.x != rhs.bounds.x {
            return lhs.bounds.x < rhs.bounds.x
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }

}
