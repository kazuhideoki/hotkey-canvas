// Background: Multi-selection needs one canonical rule set shared by command handlers and pipeline normalization.
// Responsibility: Normalize and extend selected-node sets from immutable graph snapshots.
/// Pure domain service for multi-selection state transitions.
public enum CanvasSelectionService {
    /// Normalizes selected node identifiers against visibility and focus invariants.
    /// - Parameters:
    ///   - nodeIDs: Candidate selected node identifiers.
    ///   - graph: Source graph snapshot.
    ///   - focusedNodeID: Focused node to keep selected when visible.
    /// - Returns: Canonical selected node identifiers.
    public static func normalizedSelectedNodeIDs(
        from nodeIDs: Set<CanvasNodeID>,
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID?
    ) -> Set<CanvasNodeID> {
        let visibleNodeIDs = CanvasFoldedSubtreeVisibilityService.visibleNodeIDs(in: graph)
        guard let focusedNodeID, visibleNodeIDs.contains(focusedNodeID) else {
            return []
        }
        var normalized = nodeIDs.intersection(visibleNodeIDs)
        normalized.insert(focusedNodeID)
        return normalized
    }

    /// Normalizes the graph-owned selected node identifiers.
    /// - Parameter graph: Source graph snapshot.
    /// - Returns: Canonical selected node identifiers for the graph.
    public static func normalizedSelectedNodeIDs(in graph: CanvasGraph) -> Set<CanvasNodeID> {
        normalizedSelectedNodeIDs(
            from: graph.selectedNodeIDs,
            in: graph,
            focusedNodeID: graph.focusedNodeID
        )
    }
}
