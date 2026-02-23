import Domain

// Background: Tree editing commands need a stable sibling-order model that does not depend on temporary bounds.
// Responsibility: Provide parent-child edge ordering helpers shared by add/move/paste use cases.
extension ApplyCanvasCommandsUseCase {
    /// Returns parent-child edges under the given parent sorted by effective sibling order.
    /// - Parameters:
    ///   - parentID: Parent node identifier.
    ///   - graph: Current graph snapshot.
    /// - Returns: Ordered parent-child edges.
    func parentChildEdges(of parentID: CanvasNodeID, in graph: CanvasGraph) -> [CanvasEdge] {
        let parentEdges = graph.edgesByID.values
            .filter {
                $0.relationType == .parentChild
                    && $0.fromNodeID == parentID
                    && graph.nodesByID[$0.toNodeID] != nil
            }
        let effectiveOrderByEdgeID = effectiveParentChildOrderByEdgeID(
            parentEdges: parentEdges,
            in: graph
        )
        return parentEdges.sorted { lhs, rhs in
            let lhsOrder = effectiveOrderByEdgeID[lhs.id] ?? Int.max
            let rhsOrder = effectiveOrderByEdgeID[rhs.id] ?? Int.max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            guard
                let lhsNode = graph.nodesByID[lhs.toNodeID],
                let rhsNode = graph.nodesByID[rhs.toNodeID]
            else {
                return lhs.id.rawValue < rhs.id.rawValue
            }
            if isNodeVisuallyOrderedBefore(lhsNode, rhsNode) {
                return true
            }
            if isNodeVisuallyOrderedBefore(rhsNode, lhsNode) {
                return false
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    /// Returns the next append position under the parent based on effective sibling order.
    /// - Parameters:
    ///   - parentID: Parent node identifier.
    ///   - graph: Current graph snapshot.
    /// - Returns: Next sibling order value.
    func nextParentChildOrder(for parentID: CanvasNodeID, in graph: CanvasGraph) -> Int {
        let parentEdges = parentChildEdges(of: parentID, in: graph)
        guard !parentEdges.isEmpty else {
            return 0
        }
        let effectiveOrderByEdgeID = effectiveParentChildOrderByEdgeID(
            parentEdges: parentEdges,
            in: graph
        )
        let maxOrder = parentEdges.compactMap { effectiveOrderByEdgeID[$0.id] }.max() ?? -1
        return maxOrder + 1
    }

    /// Rewrites sibling order values under one parent to contiguous indexes.
    /// - Parameters:
    ///   - parentID: Parent node identifier.
    ///   - graph: Graph snapshot to normalize.
    /// - Returns: Graph with normalized `parentChildOrder` values.
    func normalizeParentChildOrder(for parentID: CanvasNodeID, in graph: CanvasGraph) -> CanvasGraph {
        let sortedEdges = parentChildEdges(of: parentID, in: graph)
        guard !sortedEdges.isEmpty else {
            return graph
        }

        var edgesByID = graph.edgesByID
        for (index, edge) in sortedEdges.enumerated() {
            guard edge.parentChildOrder != index else {
                continue
            }
            edgesByID[edge.id] = edgeByReplacingParentChildOrder(edge: edge, parentChildOrder: index)
        }
        return CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: edgesByID,
            focusedNodeID: graph.focusedNodeID,
            selectedNodeIDs: graph.selectedNodeIDs,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }

    /// Shifts sibling order values greater than or equal to the threshold under one parent.
    /// - Parameters:
    ///   - parentID: Parent node identifier.
    ///   - order: Inclusive minimum sibling order to shift.
    ///   - delta: Signed offset to apply.
    ///   - graph: Graph snapshot to update.
    /// - Returns: Graph with shifted sibling order values.
    func shiftParentChildOrder(
        for parentID: CanvasNodeID,
        atOrAfter order: Int,
        by delta: Int,
        in graph: CanvasGraph
    ) -> CanvasGraph {
        guard delta != 0 else {
            return graph
        }
        let normalizedGraph = normalizeParentChildOrder(for: parentID, in: graph)
        var edgesByID = normalizedGraph.edgesByID
        for edge in parentChildEdges(of: parentID, in: normalizedGraph) {
            guard let currentOrder = edge.parentChildOrder, currentOrder >= order else {
                continue
            }
            edgesByID[edge.id] = edgeByReplacingParentChildOrder(
                edge: edge,
                parentChildOrder: currentOrder + delta
            )
        }
        return CanvasGraph(
            nodesByID: normalizedGraph.nodesByID,
            edgesByID: edgesByID,
            focusedNodeID: normalizedGraph.focusedNodeID,
            selectedNodeIDs: normalizedGraph.selectedNodeIDs,
            collapsedRootNodeIDs: normalizedGraph.collapsedRootNodeIDs,
            areasByID: normalizedGraph.areasByID
        )
    }

    /// Returns one incoming parent-child edge selected deterministically for a child.
    /// - Parameters:
    ///   - nodeID: Child node identifier.
    ///   - graph: Current graph snapshot.
    /// - Returns: Incoming parent-child edge when present.
    func parentChildIncomingEdge(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasEdge? {
        graph.edgesByID.values
            .filter {
                $0.relationType == .parentChild
                    && $0.toNodeID == nodeID
            }
            .sorted { lhs, rhs in
                if lhs.fromNodeID != rhs.fromNodeID {
                    return lhs.fromNodeID.rawValue < rhs.fromNodeID.rawValue
                }
                return lhs.id.rawValue < rhs.id.rawValue
            }
            .first
    }

    /// Rebuilds an edge while replacing only the parent-child order field.
    /// - Parameters:
    ///   - edge: Source edge.
    ///   - parentChildOrder: New sibling order.
    /// - Returns: Edge with updated parent-child order.
    func edgeByReplacingParentChildOrder(
        edge: CanvasEdge,
        parentChildOrder: Int
    ) -> CanvasEdge {
        CanvasEdge(
            id: edge.id,
            fromNodeID: edge.fromNodeID,
            toNodeID: edge.toNodeID,
            relationType: edge.relationType,
            parentChildOrder: parentChildOrder,
            label: edge.label,
            metadata: edge.metadata
        )
    }

    /// Builds effective sibling order mapping by combining explicit keys and visual fallback order.
    /// - Parameters:
    ///   - parentEdges: Candidate parent-child edges under the parent.
    ///   - graph: Graph snapshot for visual fallback ordering.
    /// - Returns: Effective sibling order keyed by edge identifier.
    private func effectiveParentChildOrderByEdgeID(
        parentEdges: [CanvasEdge],
        in graph: CanvasGraph
    ) -> [CanvasEdgeID: Int] {
        let fallbackSortedEdges = parentEdges.sorted { lhs, rhs in
            guard
                let lhsNode = graph.nodesByID[lhs.toNodeID],
                let rhsNode = graph.nodesByID[rhs.toNodeID]
            else {
                return lhs.id.rawValue < rhs.id.rawValue
            }
            if isNodeVisuallyOrderedBefore(lhsNode, rhsNode) {
                return true
            }
            if isNodeVisuallyOrderedBefore(rhsNode, lhsNode) {
                return false
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
        let fallbackOrderByEdgeID = Dictionary(
            uniqueKeysWithValues: fallbackSortedEdges.enumerated().map { (index, edge) in
                (edge.id, index)
            }
        )
        return Dictionary(
            uniqueKeysWithValues: parentEdges.map { edge in
                let effectiveOrder = edge.parentChildOrder ?? fallbackOrderByEdgeID[edge.id] ?? Int.max
                return (edge.id, effectiveOrder)
            }
        )
    }

    private func isNodeVisuallyOrderedBefore(_ lhs: CanvasNode, _ rhs: CanvasNode) -> Bool {
        if lhs.bounds.y != rhs.bounds.y {
            return lhs.bounds.y < rhs.bounds.y
        }
        if lhs.bounds.x != rhs.bounds.x {
            return lhs.bounds.x < rhs.bounds.x
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }
}
