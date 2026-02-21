import Domain

// Background: Phase-1 area policy requires area metadata on non-empty graphs.
// Responsibility: Provide test-only helper to backfill one default tree area.
extension CanvasGraph {
    /// Returns graph unchanged when area metadata exists, otherwise assigns all nodes to default tree area.
    func withDefaultTreeAreaIfMissing() -> CanvasGraph {
        if nodesByID.isEmpty || !areasByID.isEmpty {
            return self
        }
        return CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: edgesByID,
            focusedNodeID: focusedNodeID,
            collapsedRootNodeIDs: collapsedRootNodeIDs,
            areasByID: [
                .defaultTree: CanvasArea(
                    id: .defaultTree,
                    nodeIDs: Set(nodesByID.keys),
                    editingMode: .tree
                )
            ]
        )
    }
}
