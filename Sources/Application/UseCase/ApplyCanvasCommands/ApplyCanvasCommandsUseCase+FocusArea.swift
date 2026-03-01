import Domain

// Background: Area-target operations need an explicit focus state that is distinct from node and edge focus.
// Responsibility: Resolve and apply area focus while keeping a node anchor for existing command compatibility.
extension ApplyCanvasCommandsUseCase {
    /// Focuses one explicit area and keeps one visible node as anchor.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - areaID: Area identifier to focus.
    /// - Returns: Mutation result with updated focus state, or no-op when focusing is not possible.
    func focusArea(in graph: CanvasGraph, areaID: CanvasAreaID) -> CanvasMutationResult {
        guard let area = graph.areasByID[areaID] else {
            return noOpMutationResult(for: graph)
        }

        guard let anchorNodeID = areaAnchorNodeID(in: area, graph: graph) else {
            return noOpMutationResult(for: graph)
        }

        let nextSelectedNodeIDs = CanvasSelectionService.normalizedSelectedNodeIDs(
            from: [anchorNodeID],
            in: graph,
            focusedNodeID: anchorNodeID
        )
        let nextFocusedElement: CanvasFocusedElement = .area(areaID)
        guard
            graph.focusedNodeID != anchorNodeID
                || graph.focusedElement != nextFocusedElement
                || graph.selectedNodeIDs != nextSelectedNodeIDs
                || !graph.selectedEdgeIDs.isEmpty
        else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: anchorNodeID,
            focusedElement: nextFocusedElement,
            selectedNodeIDs: nextSelectedNodeIDs,
            selectedEdgeIDs: [],
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
                needsFocusNormalization: true
            )
        )
    }

    private func areaAnchorNodeID(in area: CanvasArea, graph: CanvasGraph) -> CanvasNodeID? {
        let visibleNodeIDs = CanvasFoldedSubtreeVisibilityService.visibleNodeIDs(in: graph)
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
