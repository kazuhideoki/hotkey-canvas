import Domain

// Background: Diagram-mode node move must feel like continuous grid movement with or without a connected anchor.
// Responsibility: Resolve diagram move target from current slot.
// Skip anchor-overlapping candidates only when a connected anchor exists.
extension ApplyCanvasCommandsUseCase {
    private static let diagramSemanticHorizontalGap: Double = CanvasDefaultNodeDistance.diagramHorizontal
    private static let diagramSemanticVerticalGap: Double = CanvasDefaultNodeDistance.vertical(for: .diagram)

    func moveNodeByDirectionSlot(
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID,
        targetNodeIDs: [CanvasNodeID],
        direction: CanvasNodeMoveDirection
    ) -> CanvasMutationResult {
        moveDiagramNode(
            in: graph,
            focusedNodeID: focusedNodeID,
            targetNodeIDs: targetNodeIDs,
            direction: direction,
            stepMultiplier: CanvasDefaultNodeDistance.diagramMoveStepMultiplier
        )
    }

    func nudgeNodeByDirectionSlot(
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID,
        targetNodeIDs: [CanvasNodeID],
        direction: CanvasNodeMoveDirection
    ) -> CanvasMutationResult {
        moveDiagramNode(
            in: graph,
            focusedNodeID: focusedNodeID,
            targetNodeIDs: targetNodeIDs,
            direction: direction,
            stepMultiplier: CanvasDefaultNodeDistance.diagramNudgeStepMultiplier
        )
    }

    private func moveDiagramNode(
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID,
        targetNodeIDs: [CanvasNodeID],
        direction: CanvasNodeMoveDirection,
        stepMultiplier: Double
    ) -> CanvasMutationResult {
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return noOpMutationResult(for: graph)
        }
        guard stepMultiplier > 0 else {
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
            direction: unit,
            stepMultiplier: stepMultiplier
        )
        guard targetBounds != focusedNode.bounds else {
            return noOpMutationResult(for: graph)
        }
        let deltaX = targetBounds.x - focusedNode.bounds.x
        let deltaY = targetBounds.y - focusedNode.bounds.y
        let nodeOverrides = movedDiagramNodes(
            in: graph,
            focusedNodeID: focusedNodeID,
            targetNodeIDs: targetNodeIDs,
            focusedTargetBounds: targetBounds,
            translation: (dx: deltaX, dy: deltaY)
        )
        guard !nodeOverrides.isEmpty else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID.merging(nodeOverrides, uniquingKeysWith: { _, new in new }),
            edgesByID: graph.edgesByID,
            focusedNodeID: focusedNodeID,
            selectedNodeIDs: graph.selectedNodeIDs,
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

    private func movedDiagramNodes(
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID,
        targetNodeIDs: [CanvasNodeID],
        focusedTargetBounds: CanvasBounds,
        translation: (dx: Double, dy: Double)
    ) -> [CanvasNodeID: CanvasNode] {
        let uniqueTargetNodeIDs = Array(Set(targetNodeIDs))
        var nodeOverrides: [CanvasNodeID: CanvasNode] = [:]
        for nodeID in uniqueTargetNodeIDs {
            guard let node = graph.nodesByID[nodeID] else {
                continue
            }
            let bounds =
                if nodeID == focusedNodeID {
                    focusedTargetBounds
                } else {
                    translateBounds(node.bounds, dx: translation.dx, dy: translation.dy)
                }
            nodeOverrides[nodeID] = CanvasNode(
                id: node.id,
                kind: node.kind,
                text: node.text,
                attachments: node.attachments,
                bounds: bounds,
                metadata: node.metadata,
                markdownStyleEnabled: node.markdownStyleEnabled
            )
        }
        return nodeOverrides
    }

    private func moveNodeTargetBoundsByDiagramGrid(
        focusedNode: CanvasNode,
        anchorNode: CanvasNode?,
        direction: (dx: Int, dy: Int),
        stepMultiplier: Double
    ) -> CanvasBounds {
        let distance = diagramMoveDistance(anchorNode: anchorNode, focusedNode: focusedNode)
        let deltaX = Double(direction.dx) * distance.horizontal * stepMultiplier
        let deltaY = Double(direction.dy) * distance.vertical * stepMultiplier
        var targetBounds = translateBounds(focusedNode.bounds, dx: deltaX, dy: deltaY)

        if let anchorNode {
            targetBounds = clampDiagramTargetBoundsByAnchorDistance(
                targetBounds,
                anchorBounds: anchorNode.bounds,
                direction: direction,
                minimumAxisDistance: (
                    horizontal: abs(deltaX),
                    vertical: abs(deltaY)
                )
            )
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

    private func clampDiagramTargetBoundsByAnchorDistance(
        _ targetBounds: CanvasBounds,
        anchorBounds: CanvasBounds,
        direction: (dx: Int, dy: Int),
        minimumAxisDistance: (horizontal: Double, vertical: Double)
    ) -> CanvasBounds {
        var clampedBounds = targetBounds
        let anchorCenterX = anchorBounds.x + (anchorBounds.width / 2)
        let anchorCenterY = anchorBounds.y + (anchorBounds.height / 2)

        if direction.dx != 0,
            minimumAxisDistance.horizontal > 0,
            verticalRangesOverlap(clampedBounds, anchorBounds)
        {
            let targetCenterX = clampedBounds.x + (clampedBounds.width / 2)
            let centerDeltaX = targetCenterX - anchorCenterX
            if abs(centerDeltaX) < minimumAxisDistance.horizontal {
                let side = axisSign(for: centerDeltaX, fallback: direction.dx)
                let clampedCenterX = anchorCenterX + (Double(side) * minimumAxisDistance.horizontal)
                clampedBounds = translateBounds(
                    clampedBounds,
                    dx: clampedCenterX - targetCenterX,
                    dy: 0
                )
            }
        }

        if direction.dy != 0,
            minimumAxisDistance.vertical > 0,
            horizontalRangesOverlap(clampedBounds, anchorBounds)
        {
            let targetCenterY = clampedBounds.y + (clampedBounds.height / 2)
            let centerDeltaY = targetCenterY - anchorCenterY
            if abs(centerDeltaY) < minimumAxisDistance.vertical {
                let side = axisSign(for: centerDeltaY, fallback: direction.dy)
                let clampedCenterY = anchorCenterY + (Double(side) * minimumAxisDistance.vertical)
                clampedBounds = translateBounds(
                    clampedBounds,
                    dx: 0,
                    dy: clampedCenterY - targetCenterY
                )
            }
        }

        return clampedBounds
    }

    private func axisSign(for delta: Double, fallback: Int) -> Int {
        if delta > 0 {
            return 1
        }
        if delta < 0 {
            return -1
        }
        return fallback >= 0 ? 1 : -1
    }

    private func horizontalRangesOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds) -> Bool {
        lhs.x < rhs.x + rhs.width
            && lhs.x + lhs.width > rhs.x
    }

    private func verticalRangesOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds) -> Bool {
        lhs.y < rhs.y + rhs.height
            && lhs.y + lhs.height > rhs.y
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
