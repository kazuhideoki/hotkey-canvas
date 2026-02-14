import Domain

// Background: Keyboard-driven navigation needs deterministic next-focus selection.
// Responsibility: Resolve the nearest valid focus candidate in a requested direction.
extension ApplyCanvasCommandsUseCase {
    func moveFocus(in graph: CanvasGraph, direction: CanvasFocusDirection) -> CanvasGraph {
        let sorted = sortedNodes(in: graph)
        guard !sorted.isEmpty else {
            return graph
        }

        let fallbackNode = sorted[0]
        let currentNode = graph.focusedNodeID.flatMap { graph.nodesByID[$0] } ?? fallbackNode

        let candidate =
            sorted
            .filter { $0.id != currentNode.id }
            .compactMap { makeFocusCandidate(to: $0, from: currentNode, direction: direction) }
            .min(by: isBetterFocusCandidate)

        guard let nextNode = candidate?.node else {
            guard graph.focusedNodeID != currentNode.id else {
                return graph
            }
            return CanvasGraph(
                nodesByID: graph.nodesByID,
                edgesByID: graph.edgesByID,
                focusedNodeID: currentNode.id
            )
        }

        return CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nextNode.id
        )
    }

    private func makeFocusCandidate(
        to node: CanvasNode,
        from currentNode: CanvasNode,
        direction: CanvasFocusDirection
    ) -> FocusCandidate? {
        let currentCenter = nodeCenter(for: currentNode)
        let targetCenter = nodeCenter(for: node)
        let deltaX = targetCenter.x - currentCenter.x
        let deltaY = targetCenter.y - currentCenter.y

        let axisDistance = axisDistanceForDirection(deltaX: deltaX, deltaY: deltaY, direction: direction)
        guard axisDistance > 0 else {
            return nil
        }

        return FocusCandidate(
            node: node,
            axisDistance: axisDistance,
            perpendicularDistance: perpendicularDistanceForDirection(
                deltaX: deltaX,
                deltaY: deltaY,
                direction: direction
            ),
            distance: (deltaX * deltaX) + (deltaY * deltaY)
        )
    }

    private func axisDistanceForDirection(
        deltaX: Double,
        deltaY: Double,
        direction: CanvasFocusDirection
    ) -> Double {
        switch direction {
        case .up:
            return -deltaY
        case .down:
            return deltaY
        case .left:
            return -deltaX
        case .right:
            return deltaX
        }
    }

    private func perpendicularDistanceForDirection(
        deltaX: Double,
        deltaY: Double,
        direction: CanvasFocusDirection
    ) -> Double {
        switch direction {
        case .up, .down:
            return abs(deltaX)
        case .left, .right:
            return abs(deltaY)
        }
    }

    private func isBetterFocusCandidate(_ lhs: FocusCandidate, _ rhs: FocusCandidate) -> Bool {
        if lhs.axisDistance != rhs.axisDistance {
            return lhs.axisDistance < rhs.axisDistance
        }
        if lhs.perpendicularDistance != rhs.perpendicularDistance {
            return lhs.perpendicularDistance < rhs.perpendicularDistance
        }
        if lhs.distance != rhs.distance {
            return lhs.distance < rhs.distance
        }
        return lhs.node.id.rawValue < rhs.node.id.rawValue
    }
}

private struct FocusCandidate {
    let node: CanvasNode
    let axisDistance: Double
    let perpendicularDistance: Double
    let distance: Double
}
