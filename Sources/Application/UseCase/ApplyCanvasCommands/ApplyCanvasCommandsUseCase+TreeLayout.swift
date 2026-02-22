import Domain

// Background: Multiple command handlers need one shared path to apply tree relayout after mutations.
// Responsibility: Apply tree-layout bounds updates to the current graph snapshot.
extension ApplyCanvasCommandsUseCase {
    private static let treeLayoutVerticalSpacing: Double = 24
    private static let treeLayoutHorizontalSpacing: Double = 32
    private static let treeLayoutRootSpacing: Double = 48

    /// Recomputes all parent-child tree node positions with symmetric vertical distribution.
    /// - Parameter graph: Graph to relayout.
    /// - Returns: Graph with updated tree node bounds.
    func relayoutParentChildTrees(in graph: CanvasGraph) -> CanvasGraph {
        let updatedBoundsByNodeID = CanvasTreeLayoutService.relayoutParentChildTrees(
            in: graph,
            verticalSpacing: Self.treeLayoutVerticalSpacing,
            horizontalSpacing: Self.treeLayoutHorizontalSpacing,
            rootSpacing: Self.treeLayoutRootSpacing
        )
        guard !updatedBoundsByNodeID.isEmpty else {
            return graph
        }

        var nodesByID = graph.nodesByID
        for nodeID in updatedBoundsByNodeID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let bounds = updatedBoundsByNodeID[nodeID] else {
                continue
            }
            guard let node = nodesByID[nodeID] else {
                continue
            }
            nodesByID[nodeID] = CanvasNode(
                id: node.id,
                kind: node.kind,
                text: node.text,
                imagePath: node.imagePath,
                bounds: bounds,
                metadata: node.metadata
            )
        }

        return CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }
}
