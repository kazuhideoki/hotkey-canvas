import Domain

// Background: Multiple command handlers need one shared path to apply tree relayout after mutations.
// Responsibility: Apply tree-layout bounds updates to the current graph snapshot.
extension ApplyCanvasCommandsUseCase {
    /// Recomputes all parent-child tree node positions with symmetric vertical distribution.
    /// - Parameter graph: Graph to relayout.
    /// - Returns: Graph with updated tree node bounds.
    func relayoutParentChildTrees(in graph: CanvasGraph) -> CanvasGraph {
        let updatedBoundsByNodeID = CanvasTreeLayoutService.relayoutParentChildTrees(
            in: graph,
            verticalSpacing: CanvasDefaultNodeDistance.vertical(for: .tree),
            horizontalSpacing: CanvasDefaultNodeDistance.treeHorizontal,
            rootSpacing: CanvasDefaultNodeDistance.treeRootVertical
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
                attachments: node.attachments,
                bounds: bounds,
                metadata: node.metadata,
                markdownStyleEnabled: node.markdownStyleEnabled
            )
        }

        return CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            selectedNodeIDs: graph.selectedNodeIDs,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }
}
