import Foundation

// Background: Callers need one stable entry to recompute parent-child layout after graph mutations.
// Responsibility: Expose relayout API and normalize layout parameters.
extension CanvasTreeLayoutService {
    struct LayoutConfig {
        let verticalSpacing: Double
        let horizontalSpacing: Double
        let rootSpacing: Double
    }

    // MARK: - Public API

    /// Recomputes bounds for nodes connected by parent-child edges.
    /// - Parameters:
    ///   - graph: Source graph snapshot.
    ///   - verticalSpacing: Minimum vertical spacing between sibling subtrees.
    ///   - horizontalSpacing: Horizontal spacing from parent to child.
    ///   - rootSpacing: Vertical spacing between root trees in one component.
    /// - Returns: Updated bounds keyed by node identifier.
    public static func relayoutParentChildTrees(
        in graph: CanvasGraph,
        verticalSpacing: Double = 24,
        horizontalSpacing: Double = 32,
        rootSpacing: Double = 48
    ) -> [CanvasNodeID: CanvasBounds] {
        let config = LayoutConfig(
            verticalSpacing: max(0, verticalSpacing),
            horizontalSpacing: max(0, horizontalSpacing),
            rootSpacing: max(0, rootSpacing)
        )
        let parentChildEdges = validParentChildEdges(in: graph)
        guard !parentChildEdges.isEmpty else {
            return [:]
        }

        let components = makeComponents(from: parentChildEdges)
        var updatedBoundsByNodeID: [CanvasNodeID: CanvasBounds] = [:]
        for componentNodeIDs in components {
            let componentBounds = relayoutComponent(
                nodeIDs: componentNodeIDs,
                edges: parentChildEdges,
                graph: graph,
                config: config
            )
            for (nodeID, bounds) in componentBounds {
                updatedBoundsByNodeID[nodeID] = bounds
            }
        }
        return updatedBoundsByNodeID
    }
}
