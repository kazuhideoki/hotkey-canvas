import Domain

// Background: Add-node placement reuses stable geometry helpers across tree and diagram flows.
// Responsibility: Provide placement-anchor and ordering helpers shared by node insertion logic.
extension ApplyCanvasCommandsUseCase {
    /// - Parameter graph: Current canvas graph.
    /// - Returns: Parent node and area used for placement, or `nil` when graph is empty.
    func addNodePlacementAnchor(in graph: CanvasGraph) -> (parentNode: CanvasNode, area: CanvasNodeArea)? {
        let areas = CanvasAreaLayoutService.makeParentChildAreas(in: graph)
        guard let bottomArea = areas.max(by: isAreaHigher(_:_:)) else {
            return nil
        }

        let parentNodes = bottomArea.nodeIDs
            .compactMap { graph.nodesByID[$0] }
            .filter { isTopLevelParent($0.id, in: graph) }
            .sorted(by: isNodeAbove(_:_:))
        if let parentNode = parentNodes.first {
            return (parentNode, bottomArea)
        }

        // Cyclic or malformed graphs may have no top-level parent; use stable visual order.
        guard
            let fallbackNode = bottomArea.nodeIDs
                .compactMap({ graph.nodesByID[$0] })
                .sorted(by: isNodeAbove(_:_:))
                .first
        else {
            return nil
        }
        return (fallbackNode, bottomArea)
    }

    /// Returns the first existing area that overlaps the candidate with required area spacing.
    /// - Parameters:
    ///   - candidate: Node bounds under evaluation.
    ///   - areas: Existing parent-child areas.
    /// - Returns: First overlapped area in deterministic order, or `nil`.
    func firstOverlappedArea(for candidate: CanvasBounds, in areas: [CanvasNodeArea]) -> CanvasNodeArea? {
        let candidateRect = CanvasRect(
            minX: candidate.x,
            minY: candidate.y,
            width: candidate.width,
            height: candidate.height
        )
        let expandedCandidate = candidateRect.expanded(
            horizontal: Self.areaCollisionSpacing / 2,
            vertical: Self.areaCollisionSpacing / 2
        )

        return
            areas
            .sorted(by: isAreaAbove(_:_:))
            .first { area in
                let expandedArea = area.bounds.expanded(
                    horizontal: Self.areaCollisionSpacing / 2,
                    vertical: Self.areaCollisionSpacing / 2
                )
                return expandedCandidate.intersects(expandedArea)
            }
    }

    /// Returns deterministic visual ordering for nodes.
    func isNodeAbove(_ lhs: CanvasNode, _ rhs: CanvasNode) -> Bool {
        if lhs.bounds.y == rhs.bounds.y {
            if lhs.bounds.x == rhs.bounds.x {
                return lhs.id.rawValue < rhs.id.rawValue
            }
            return lhs.bounds.x < rhs.bounds.x
        }
        return lhs.bounds.y < rhs.bounds.y
    }

    /// Returns deterministic visual ordering for areas.
    func isAreaAbove(_ lhs: CanvasNodeArea, _ rhs: CanvasNodeArea) -> Bool {
        if lhs.bounds.minY == rhs.bounds.minY {
            if lhs.bounds.minX == rhs.bounds.minX {
                return lhs.id.rawValue < rhs.id.rawValue
            }
            return lhs.bounds.minX < rhs.bounds.minX
        }
        return lhs.bounds.minY < rhs.bounds.minY
    }

    /// Returns whether lhs should be ordered before rhs when selecting bottom-most area.
    func isAreaHigher(_ lhs: CanvasNodeArea, _ rhs: CanvasNodeArea) -> Bool {
        if lhs.bounds.maxY == rhs.bounds.maxY {
            return isAreaAbove(lhs, rhs)
        }
        return lhs.bounds.maxY < rhs.bounds.maxY
    }

    /// Returns the preferred incoming anchor node for a focused diagram node.
    func diagramIncomingAnchorNode(
        of focusedNodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> CanvasNode? {
        let incomingEdges = graph.edgesByID.values
            .filter { $0.toNodeID == focusedNodeID && graph.nodesByID[$0.fromNodeID] != nil }
            .sorted(by: isPreferredPlacementAnchorEdge)
        guard let edge = incomingEdges.first else {
            return nil
        }
        return graph.nodesByID[edge.fromNodeID]
    }

    /// Maps anchor->focused relation to one cardinal unit direction for chained diagram placement.
    /// Diagonal relations are snapped to the dominant axis (horizontal on ties).
    func diagramDirectionalUnit(
        from anchorNode: CanvasNode,
        to focusedNode: CanvasNode
    ) -> (dx: Int, dy: Int)? {
        let deltaX = focusedNode.bounds.x - anchorNode.bounds.x
        let deltaY = focusedNode.bounds.y - anchorNode.bounds.y
        let epsilon = 0.001
        if abs(deltaX) <= epsilon, abs(deltaY) <= epsilon {
            return nil
        }
        if abs(deltaX) >= abs(deltaY) {
            return (deltaX >= 0 ? 1 : -1, 0)
        }
        return (0, deltaY >= 0 ? 1 : -1)
    }

    /// Returns deterministic edge priority for placement anchor selection.
    func isPreferredPlacementAnchorEdge(_ lhs: CanvasEdge, _ rhs: CanvasEdge) -> Bool {
        let lhsPriority = edgePriorityForPlacementAnchor(lhs)
        let rhsPriority = edgePriorityForPlacementAnchor(rhs)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    /// Defines edge priority so normal links are used before structural links.
    func edgePriorityForPlacementAnchor(_ edge: CanvasEdge) -> Int {
        if edge.relationType == .normal {
            return 0
        }
        if edge.relationType == .parentChild {
            return 1
        }
        return 2
    }
}
