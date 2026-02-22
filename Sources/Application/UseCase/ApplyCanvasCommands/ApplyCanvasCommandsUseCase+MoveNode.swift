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
        if areaMode == .diagram {
            return moveNodeByNudge(in: graph, direction: direction)
        }

        let graphAfterMutation: CanvasGraph
        switch direction {
        case .up:
            graphAfterMutation = try moveNodeVertically(in: graph, offset: -1)
        case .down:
            graphAfterMutation = try moveNodeVertically(in: graph, offset: 1)
        case .left:
            graphAfterMutation = try outdentNode(in: graph)
        case .right:
            graphAfterMutation = try indentNode(in: graph)
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
}

extension ApplyCanvasCommandsUseCase {
    private static let orderingEpsilon: Double = 0.001
    private static let indentHorizontalGap: Double = 32
    private static let diagramNudgeStep: Double = 24

    private func moveNodeByNudge(
        in graph: CanvasGraph,
        direction: CanvasNodeMoveDirection
    ) -> CanvasMutationResult {
        guard let focusedNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return noOpMutationResult(for: graph)
        }

        let delta = diagramNudgeDelta(for: direction)
        guard delta.dx != 0 || delta.dy != 0 else {
            return noOpMutationResult(for: graph)
        }

        let movedNode = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            bounds: CanvasBounds(
                x: focusedNode.bounds.x + delta.dx,
                y: focusedNode.bounds.y + delta.dy,
                width: focusedNode.bounds.width,
                height: focusedNode.bounds.height
            ),
            metadata: focusedNode.metadata
        )
        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID.merging(
                [focusedNodeID: movedNode],
                uniquingKeysWith: { _, new in new }
            ),
            edgesByID: graph.edgesByID,
            focusedNodeID: focusedNodeID,
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
            ),
            areaLayoutSeedNodeID: focusedNodeID
        )
    }

    private func diagramNudgeDelta(for direction: CanvasNodeMoveDirection) -> (dx: Double, dy: Double) {
        switch direction {
        case .up:
            return (0, -Self.diagramNudgeStep)
        case .down:
            return (0, Self.diagramNudgeStep)
        case .left:
            return (-Self.diagramNudgeStep, 0)
        case .right:
            return (Self.diagramNudgeStep, 0)
        }
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

        let focusedWithMovedBounds = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            imagePath: focusedNode.imagePath,
            bounds: CanvasBounds(
                x: destination.bounds.x,
                y: destination.bounds.y,
                width: focusedNode.bounds.width,
                height: focusedNode.bounds.height
            ),
            metadata: focusedNode.metadata,
            markdownStyleEnabled: focusedNode.markdownStyleEnabled
        )
        let destinationWithMovedBounds = CanvasNode(
            id: destination.id,
            kind: destination.kind,
            text: destination.text,
            imagePath: destination.imagePath,
            bounds: CanvasBounds(
                x: focusedNode.bounds.x,
                y: focusedNode.bounds.y,
                width: destination.bounds.width,
                height: destination.bounds.height
            ),
            metadata: destination.metadata,
            markdownStyleEnabled: destination.markdownStyleEnabled
        )
        let graphAfterSwap = CanvasGraph(
            nodesByID: graph.nodesByID.merging(
                [
                    focusedNodeID: focusedWithMovedBounds,
                    destination.id: destinationWithMovedBounds,
                ],
                uniquingKeysWith: { _, new in new }
            ),
            edgesByID: graph.edgesByID,
            focusedNodeID: focusedNodeID,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
        return graphAfterSwap
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

        var nextGraph = try CanvasGraphCRUDService.deleteEdge(id: parentEdge.id, in: graph).get()
        nextGraph = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: grandparentNode.id, to: focusedNodeID),
            in: nextGraph
        ).get()

        let updatedFocusedNode = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            imagePath: focusedNode.imagePath,
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
            collapsedRootNodeIDs: nextGraph.collapsedRootNodeIDs,
            areasByID: nextGraph.areasByID
        )

        return nextGraph
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
        nextGraph = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: newParent.id, to: focusedNodeID),
            in: nextGraph
        ).get()

        let updatedFocusedNode = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            imagePath: focusedNode.imagePath,
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

    private func parentChildIncomingEdge(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasEdge? {
        graph.edgesByID.values
            .filter { $0.relationType == .parentChild && $0.toNodeID == nodeID }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first
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
