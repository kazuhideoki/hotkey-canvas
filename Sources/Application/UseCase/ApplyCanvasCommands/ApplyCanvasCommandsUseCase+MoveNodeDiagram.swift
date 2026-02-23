import Domain

// Background: Diagram-mode node move must feel like continuous grid movement with or without a connected anchor.
// Responsibility: Resolve diagram move target from current slot.
// Skip anchor-overlapping candidates only when a connected anchor exists.
extension ApplyCanvasCommandsUseCase {
    private static let diagramSemanticHorizontalGap: Double = CanvasDefaultNodeDistance.diagramHorizontal
    private static let diagramSemanticVerticalGap: Double = CanvasDefaultNodeDistance.vertical(for: .diagram)

    func moveNodeByDirectionSlot(
        in graph: CanvasGraph,
        direction: CanvasNodeMoveDirection
    ) -> CanvasMutationResult {
        guard let focusedNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return noOpMutationResult(for: graph)
        }
        let unit = diagramUnitVector(for: direction)
        guard unit.dx != 0 || unit.dy != 0 else {
            return noOpMutationResult(for: graph)
        }
        let anchorNode = connectedAnchorNode(of: focusedNodeID, in: graph)

        let targetBounds = moveNodeTargetBoundsByDiagramGrid(
            focusedNode: focusedNode,
            anchorNode: anchorNode,
            direction: unit
        )
        guard targetBounds != focusedNode.bounds else {
            return noOpMutationResult(for: graph)
        }

        let movedNode = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            attachments: focusedNode.attachments,
            bounds: targetBounds,
            metadata: focusedNode.metadata,
            markdownStyleEnabled: focusedNode.markdownStyleEnabled
        )
        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID.merging([focusedNodeID: movedNode], uniquingKeysWith: { _, new in new }),
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
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: focusedNodeID
        )
    }

    private func moveNodeTargetBoundsByDiagramGrid(
        focusedNode: CanvasNode,
        anchorNode: CanvasNode?,
        direction: (dx: Int, dy: Int)
    ) -> CanvasBounds {
        let distance = diagramMoveDistance(anchorNode: anchorNode, focusedNode: focusedNode)
        let deltaX = Double(direction.dx) * distance.horizontal
        let deltaY = Double(direction.dy) * distance.vertical
        var targetBounds = translateBounds(focusedNode.bounds, dx: deltaX, dy: deltaY)

        if let anchorNode {
            while boundsOverlap(targetBounds, anchorNode.bounds) {
                targetBounds = translateBounds(targetBounds, dx: deltaX, dy: deltaY)
            }
        }
        return targetBounds
    }

    private func diagramMoveDistance(
        anchorNode: CanvasNode?,
        focusedNode: CanvasNode
    ) -> (horizontal: Double, vertical: Double) {
        let referenceNode = anchorNode ?? focusedNode
        return (
            horizontal: ((referenceNode.bounds.width + focusedNode.bounds.width) / 2)
                + Self.diagramSemanticHorizontalGap,
            vertical: ((referenceNode.bounds.height + focusedNode.bounds.height) / 2)
                + Self.diagramSemanticVerticalGap
        )
    }

    private func translateBounds(_ bounds: CanvasBounds, dx: Double, dy: Double) -> CanvasBounds {
        return CanvasBounds(
            x: bounds.x + dx,
            y: bounds.y + dy,
            width: bounds.width,
            height: bounds.height
        )
    }

    private func diagramUnitVector(for direction: CanvasNodeMoveDirection) -> (dx: Int, dy: Int) {
        switch direction {
        case .up:
            return (0, -1)
        case .down:
            return (0, 1)
        case .left:
            return (-1, 0)
        case .right:
            return (1, 0)
        case .upLeft:
            return (-1, -1)
        case .upRight:
            return (1, -1)
        case .downLeft:
            return (-1, 1)
        case .downRight:
            return (1, 1)
        }
    }

    private func boundsOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds) -> Bool {
        lhs.x < rhs.x + rhs.width
            && lhs.x + lhs.width > rhs.x
            && lhs.y < rhs.y + rhs.height
            && lhs.y + lhs.height > rhs.y
    }

    private func connectedAnchorNode(of focusedNodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasNode? {
        let incomingEdges = graph.edgesByID.values
            .filter { $0.toNodeID == focusedNodeID && graph.nodesByID[$0.fromNodeID] != nil }
            .sorted(by: isPreferredAnchorEdge)
        if let incomingEdge = incomingEdges.first, let anchorNode = graph.nodesByID[incomingEdge.fromNodeID] {
            return anchorNode
        }

        let connectedEdges = graph.edgesByID.values
            .filter {
                ($0.fromNodeID == focusedNodeID && graph.nodesByID[$0.toNodeID] != nil)
                    || ($0.toNodeID == focusedNodeID && graph.nodesByID[$0.fromNodeID] != nil)
            }
            .sorted(by: isPreferredAnchorEdge)
        guard let edge = connectedEdges.first else {
            return nil
        }
        let anchorNodeID = edge.fromNodeID == focusedNodeID ? edge.toNodeID : edge.fromNodeID
        return graph.nodesByID[anchorNodeID]
    }

    private func isPreferredAnchorEdge(_ lhs: CanvasEdge, _ rhs: CanvasEdge) -> Bool {
        let lhsPriority = edgePriorityForAnchor(lhs)
        let rhsPriority = edgePriorityForAnchor(rhs)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    private func edgePriorityForAnchor(_ edge: CanvasEdge) -> Int {
        if edge.relationType == .normal {
            return 0
        }
        if edge.relationType == .parentChild {
            return 1
        }
        return 2
    }
}
