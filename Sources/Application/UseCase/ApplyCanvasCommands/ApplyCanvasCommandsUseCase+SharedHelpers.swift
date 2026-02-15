import Domain
import Foundation

// Background: Multiple canvas command handlers reuse placement and edge-construction helpers.
// Responsibility: Provide shared node/edge creation and placement routines.
extension ApplyCanvasCommandsUseCase {
    static let newNodeWidth: Double = 220
    static let newNodeHeight: Double = 41
    static let defaultNewNodeX: Double = 48
    static let defaultNewNodeY: Double = 48
    static let newNodeVerticalSpacing: Double = 24
    static let childHorizontalGap: Double = 32
    static let areaCollisionSpacing: Double = 32

    /// Creates a default text node using the provided bounds.
    /// - Parameter bounds: Bounds to assign to the new node.
    /// - Returns: A text node with a generated identifier.
    func makeTextNode(bounds: CanvasBounds) -> CanvasNode {
        CanvasNode(
            id: CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())"),
            kind: .text,
            text: nil,
            bounds: bounds
        )
    }

    /// Creates a parent-child edge between two nodes.
    /// - Parameters:
    ///   - parentID: Source node identifier treated as the parent.
    ///   - childID: Destination node identifier treated as the child.
    /// - Returns: A parent-child edge with a generated identifier.
    func makeParentChildEdge(from parentID: CanvasNodeID, to childID: CanvasNodeID) -> CanvasEdge {
        CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-\(UUID().uuidString.lowercased())"),
            fromNodeID: parentID,
            toNodeID: childID,
            relationType: .parentChild
        )
    }

    /// Computes bounds for a newly inserted node using default collision targets.
    /// - Parameter graph: Current canvas graph.
    /// - Returns: First available node bounds from the insertion anchor.
    func makeAvailableNewNodeBounds(in graph: CanvasGraph) -> CanvasBounds {
        let focusedNode = graph.focusedNodeID.flatMap { graph.nodesByID[$0] }
        let startX = focusedNode?.bounds.x ?? Self.defaultNewNodeX
        var startY =
            if let focusedNode {
                focusedNode.bounds.y + focusedNode.bounds.height + Self.newNodeVerticalSpacing
            } else {
                Self.defaultNewNodeY
            }

        if let focusedNodeID = graph.focusedNodeID {
            if let focusedNode {
                if let focusedArea = parentChildArea(containing: focusedNodeID, in: graph) {
                    let focusedNodeBottom = focusedNode.bounds.y + focusedNode.bounds.height
                    if focusedArea.bounds.maxY > focusedNodeBottom {
                        startY = max(startY, focusedArea.bounds.maxY + Self.areaCollisionSpacing)
                    }
                }
            }
        }

        return CanvasBounds(
            x: startX,
            y: startY,
            width: Self.newNodeWidth,
            height: Self.newNodeHeight
        )
    }

    /// Computes bounds for a newly inserted node while avoiding overlap against the given node set.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - nodeIDs: Nodes to consider as placement blockers.
    /// - Returns: First available non-overlapping bounds.
    func makeAvailableNewNodeBounds(
        in graph: CanvasGraph,
        avoiding nodeIDs: Set<CanvasNodeID>
    ) -> CanvasBounds {
        let focusedNode = graph.focusedNodeID.flatMap { graph.nodesByID[$0] }
        let startX = focusedNode?.bounds.x ?? Self.defaultNewNodeX
        let startY =
            if let focusedNode {
                focusedNode.bounds.y + focusedNode.bounds.height + Self.newNodeVerticalSpacing
            } else {
                Self.defaultNewNodeY
            }

        var candidate = CanvasBounds(
            x: startX,
            y: startY,
            width: Self.newNodeWidth,
            height: Self.newNodeHeight
        )
        let collisionNodes = nodesForPlacementCollision(in: graph, avoiding: nodeIDs)
        while let overlappedNode = firstOverlappedNode(for: candidate, in: collisionNodes) {
            candidate = CanvasBounds(
                x: candidate.x,
                y: overlappedNode.bounds.y + overlappedNode.bounds.height + Self.newNodeVerticalSpacing,
                width: candidate.width,
                height: candidate.height
            )
        }
        return candidate
    }

    /// Computes sibling-node bounds for insertion around the focused node.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - parentID: Parent node identifier shared by siblings.
    ///   - focusedNode: Focused sibling used as insertion anchor.
    ///   - position: Relative insertion side from the focused sibling.
    /// - Returns: Bounds used to create the new sibling node.
    func makeSiblingNodeBounds(
        in graph: CanvasGraph,
        parentID: CanvasNodeID,
        focusedNode: CanvasNode,
        position: CanvasSiblingNodePosition
    ) -> CanvasBounds {
        let siblingNodes = childNodes(of: parentID, in: graph)
        let focusedIndex = siblingNodes.firstIndex(where: { $0.id == focusedNode.id })
        let y = makeSiblingInsertionY(
            focusedNode: focusedNode,
            siblings: siblingNodes,
            focusedIndex: focusedIndex,
            position: position
        )

        return CanvasBounds(
            x: focusedNode.bounds.x,
            y: y,
            width: Self.newNodeWidth,
            height: Self.newNodeHeight
        )
    }

    /// Returns children of a parent sorted by visual order.
    /// - Parameters:
    ///   - parentID: Parent node identifier.
    ///   - graph: Current canvas graph.
    /// - Returns: Child nodes sorted by top-to-bottom and then left-to-right.
    func childNodes(of parentID: CanvasNodeID, in graph: CanvasGraph) -> [CanvasNode] {
        graph.edgesByID.values
            .filter {
                $0.relationType == .parentChild
                    && $0.fromNodeID == parentID
            }
            .compactMap { graph.nodesByID[$0.toNodeID] }
            .sorted { lhs, rhs in
                if lhs.bounds.y == rhs.bounds.y {
                    if lhs.bounds.x == rhs.bounds.x {
                        return lhs.id.rawValue < rhs.id.rawValue
                    }
                    return lhs.bounds.x < rhs.bounds.x
                }
                return lhs.bounds.y < rhs.bounds.y
            }
    }

    /// Computes insertion Y that preserves requested above/below order in sibling sorting.
    /// - Parameters:
    ///   - focusedNode: Focused sibling node.
    ///   - siblings: Siblings sorted by visual order.
    ///   - focusedIndex: Index of focused node inside `siblings`.
    ///   - position: Relative insertion side from focused sibling.
    /// - Returns: Candidate Y for the new sibling node.
    private func makeSiblingInsertionY(
        focusedNode: CanvasNode,
        siblings: [CanvasNode],
        focusedIndex: Int?,
        position: CanvasSiblingNodePosition
    ) -> Double {
        let orderingEpsilon = 0.001

        switch position {
        case .above:
            let upperBound = focusedNode.bounds.y - orderingEpsilon
            guard
                let focusedIndex,
                focusedIndex > 0
            else {
                return focusedNode.bounds.y - Self.newNodeHeight - Self.newNodeVerticalSpacing
            }
            let previousSibling = siblings[focusedIndex - 1]
            let lowerBound = previousSibling.bounds.y + orderingEpsilon
            guard lowerBound <= upperBound else {
                return upperBound
            }
            let midpoint = (previousSibling.bounds.y + focusedNode.bounds.y) / 2
            return max(lowerBound, min(upperBound, midpoint))
        case .below:
            let lowerBound = focusedNode.bounds.y + orderingEpsilon
            guard
                let focusedIndex,
                focusedIndex + 1 < siblings.count
            else {
                return focusedNode.bounds.y + focusedNode.bounds.height + Self.newNodeVerticalSpacing
            }
            let nextSibling = siblings[focusedIndex + 1]
            let upperBound = nextSibling.bounds.y - orderingEpsilon
            guard lowerBound <= upperBound else {
                return lowerBound
            }
            let midpoint = (focusedNode.bounds.y + nextSibling.bounds.y) / 2
            return min(upperBound, max(lowerBound, midpoint))
        }
    }

    /// Computes child-node bounds to the right of the parent while avoiding overlap.
    /// - Parameters:
    ///   - parentNode: Parent node used as placement anchor.
    ///   - graph: Current canvas graph.
    ///   - nodeIDs: Nodes to consider as placement blockers.
    /// - Returns: Non-overlapping bounds for the child node.
    func calculateChildBounds(
        for parentNode: CanvasNode,
        in graph: CanvasGraph,
        avoiding nodeIDs: Set<CanvasNodeID>
    ) -> CanvasBounds {
        let width = parentNode.bounds.width
        let height = parentNode.bounds.height
        let y = parentNode.bounds.y

        var x = parentNode.bounds.x + parentNode.bounds.width + Self.childHorizontalGap
        var candidate = CanvasBounds(x: x, y: y, width: width, height: height)
        let collisionNodes = nodesForPlacementCollision(in: graph, avoiding: nodeIDs)

        while hasOverlappingNode(candidate, in: collisionNodes) {
            x += width + Self.childHorizontalGap
            candidate = CanvasBounds(x: x, y: y, width: width, height: height)
        }
        return candidate
    }
}
