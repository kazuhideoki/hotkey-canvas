import Domain

// Background: Copy/paste must preserve source sibling ordering for stable tree relayout after paste.
// Responsibility: Provide subtree-copy ordering helpers used by copy/paste handlers.
extension ApplyCanvasCommandsUseCase {
    /// Normalizes copied parent-child edges so clipboard payload captures stable sibling order.
    /// - Parameters:
    ///   - nodeIDs: Copied node identifier set.
    ///   - graph: Source graph snapshot.
    /// - Returns: Graph snapshot where copied parent-child edges have contiguous sibling order values.
    func graphByNormalizingParentChildOrderForCopiedSubtree(
        nodeIDs: Set<CanvasNodeID>,
        in graph: CanvasGraph
    ) -> CanvasGraph {
        let parentNodeIDs = Set(
            graph.edgesByID.values.compactMap { edge -> CanvasNodeID? in
                guard edge.relationType == .parentChild else {
                    return nil
                }
                guard nodeIDs.contains(edge.fromNodeID), nodeIDs.contains(edge.toNodeID) else {
                    return nil
                }
                return edge.fromNodeID
            }
        )
        return parentNodeIDs.sorted(by: { $0.rawValue < $1.rawValue }).reduce(graph) { currentGraph, parentNodeID in
            normalizeParentChildOrder(for: parentNodeID, in: currentGraph)
        }
    }
}
