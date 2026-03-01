// Background: Focus normalization logic grew as area focus joined node/edge focus in the pipeline.
// Responsibility: Keep focus normalization helpers separated from stage orchestration for lint-sized files.
import Domain

extension CanvasCommandPipelineCoordinator {
    /// Normalizes focus to the first visible node in stable order when current focus is invalid.
    func normalizedFocusedNodeID(in graph: CanvasGraph) -> CanvasNodeID? {
        let visibleGraph = CanvasFoldedSubtreeVisibilityService.visibleGraph(from: graph)
        guard !visibleGraph.nodesByID.isEmpty else {
            return nil
        }
        if let focusedNodeID = visibleGraph.focusedNodeID, visibleGraph.nodesByID[focusedNodeID] != nil {
            return focusedNodeID
        }
        return visibleGraph.nodesByID.values
            .sorted { lhs, rhs in
                if lhs.bounds.y != rhs.bounds.y {
                    return lhs.bounds.y < rhs.bounds.y
                }
                if lhs.bounds.x != rhs.bounds.x {
                    return lhs.bounds.x < rhs.bounds.x
                }
                return lhs.id.rawValue < rhs.id.rawValue
            }
            .first?
            .id
    }

    func normalizedFocusedElement(
        in graph: CanvasGraph,
        normalizedFocusedNodeID: CanvasNodeID?
    ) -> CanvasFocusedElement? {
        guard let focusedElement = graph.focusedElement else {
            return normalizedFocusedNodeID.map { .node($0) }
        }
        switch focusedElement {
        case .node:
            return normalizedFocusedNodeID.map { .node($0) }
        case .edge(let edgeFocus):
            guard graph.edgesByID[edgeFocus.edgeID] != nil else {
                return normalizedFocusedNodeID.map { .node($0) }
            }
            return focusedElement
        case .area(let areaID):
            guard let area = graph.areasByID[areaID] else {
                return normalizedFocusedNodeID.map { .node($0) }
            }
            let visibleNodeIDs = Set(CanvasFoldedSubtreeVisibilityService.visibleGraph(from: graph).nodesByID.keys)
            if area.nodeIDs.isDisjoint(with: visibleNodeIDs) == false {
                return .area(areaID)
            }
            return normalizedFocusedNodeID.map { .node($0) }
        }
    }

    func normalizedFocusedNodeIDForNormalizedElement(
        in graph: CanvasGraph,
        normalizedFocusedNodeID: CanvasNodeID?,
        normalizedFocusedElement: CanvasFocusedElement?
    ) -> CanvasNodeID? {
        guard case .area(let areaID) = normalizedFocusedElement else {
            return normalizedFocusedNodeID
        }
        return normalizedFocusedAreaAnchorNodeID(
            in: graph,
            areaID: areaID
        ) ?? normalizedFocusedNodeID
    }

    private func normalizedFocusedAreaAnchorNodeID(
        in graph: CanvasGraph,
        areaID: CanvasAreaID
    ) -> CanvasNodeID? {
        guard let area = graph.areasByID[areaID] else {
            return nil
        }
        let visibleGraph = CanvasFoldedSubtreeVisibilityService.visibleGraph(from: graph)
        let visibleNodeIDs = Set(visibleGraph.nodesByID.keys)
        return area.nodeIDs
            .filter { visibleNodeIDs.contains($0) && graph.nodesByID[$0] != nil }
            .sorted { lhs, rhs in
                guard let lhsNode = graph.nodesByID[lhs], let rhsNode = graph.nodesByID[rhs] else {
                    return lhs.rawValue < rhs.rawValue
                }
                if lhsNode.bounds.y != rhsNode.bounds.y {
                    return lhsNode.bounds.y < rhsNode.bounds.y
                }
                if lhsNode.bounds.x != rhsNode.bounds.x {
                    return lhsNode.bounds.x < rhsNode.bounds.x
                }
                return lhs.rawValue < rhs.rawValue
            }
            .first
    }
}
