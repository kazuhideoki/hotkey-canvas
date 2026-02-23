import Domain

// Background: Move-node behavior in tree mode relies on shared ordering and position helpers.
// Responsibility: Provide peer ordering and insertion-position helpers for move-node operations.
extension ApplyCanvasCommandsUseCase {
    static let orderingEpsilon: Double = 0.001
    static let indentHorizontalGap: Double = CanvasDefaultNodeDistance.treeHorizontal

    func appendedChildY(
        under newParent: CanvasNode,
        existingChildren: [CanvasNode]
    ) -> Double {
        guard !existingChildren.isEmpty else {
            return newParent.bounds.y
        }
        let deepestBottomY =
            existingChildren
            .map { $0.bounds.y + $0.bounds.height }
            .max() ?? newParent.bounds.y
        return deepestBottomY + Self.newNodeVerticalSpacing
    }

    func orderedPeerNodes(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> [CanvasNode] {
        if let parentID = parentNodeID(of: nodeID, in: graph) {
            return childNodes(of: parentID, in: graph)
        }
        return graph.nodesByID.values
            .filter { isTopLevelParent($0.id, in: graph) }
            .sorted(by: isPeerNodeOrderedBefore)
    }

    func isPeerNodeOrderedBefore(_ lhs: CanvasNode, _ rhs: CanvasNode) -> Bool {
        if lhs.bounds.y != rhs.bounds.y {
            return lhs.bounds.y < rhs.bounds.y
        }
        if lhs.bounds.x != rhs.bounds.x {
            return lhs.bounds.x < rhs.bounds.x
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }
}
