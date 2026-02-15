import Domain
import Foundation

// Background: Multiple canvas command handlers reuse placement, graph traversal, and geometry helpers.
// Responsibility: Provide shared helper routines used across ApplyCanvasCommandsUseCase command files.
extension ApplyCanvasCommandsUseCase {
    private static let newNodeWidth: Double = 220
    private static let newNodeHeight: Double = 120
    private static let defaultNewNodeX: Double = 48
    private static let defaultNewNodeY: Double = 48
    private static let newNodeVerticalSpacing: Double = 24
    private static let childHorizontalGap: Double = 32

    func makeTextNode(bounds: CanvasBounds) -> CanvasNode {
        CanvasNode(
            id: CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())"),
            kind: .text,
            text: nil,
            bounds: bounds
        )
    }

    func makeParentChildEdge(from parentID: CanvasNodeID, to childID: CanvasNodeID) -> CanvasEdge {
        CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-\(UUID().uuidString.lowercased())"),
            fromNodeID: parentID,
            toNodeID: childID,
            relationType: .parentChild
        )
    }

    func makeAvailableNewNodeBounds(in graph: CanvasGraph) -> CanvasBounds {
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
        let sorted = sortedNodes(in: graph)
        while let overlappedNode = firstOverlappedNode(for: candidate, in: sorted) {
            candidate = CanvasBounds(
                x: candidate.x,
                y: overlappedNode.bounds.y + overlappedNode.bounds.height + Self.newNodeVerticalSpacing,
                width: candidate.width,
                height: candidate.height
            )
        }
        return candidate
    }

    func makeSiblingNodeBounds(
        in graph: CanvasGraph,
        focusedNode: CanvasNode,
        position: CanvasSiblingNodePosition
    ) -> CanvasBounds {
        switch position {
        case .above:
            return CanvasBounds(
                x: focusedNode.bounds.x,
                y: focusedNode.bounds.y - Self.newNodeHeight - Self.newNodeVerticalSpacing,
                width: Self.newNodeWidth,
                height: Self.newNodeHeight
            )
        case .below:
            var candidate = CanvasBounds(
                x: focusedNode.bounds.x,
                y: focusedNode.bounds.y + focusedNode.bounds.height + Self.newNodeVerticalSpacing,
                width: Self.newNodeWidth,
                height: Self.newNodeHeight
            )
            let sorted = sortedNodes(in: graph)
            while let overlappedNode = firstOverlappedNode(for: candidate, in: sorted) {
                candidate = CanvasBounds(
                    x: candidate.x,
                    y: overlappedNode.bounds.y + overlappedNode.bounds.height + Self.newNodeVerticalSpacing,
                    width: candidate.width,
                    height: candidate.height
                )
            }
            return candidate
        }
    }

    func calculateChildBounds(for parentNode: CanvasNode, in graph: CanvasGraph) -> CanvasBounds {
        let width = parentNode.bounds.width
        let height = parentNode.bounds.height
        let y = parentNode.bounds.y

        var x = parentNode.bounds.x + parentNode.bounds.width + Self.childHorizontalGap
        var candidate = CanvasBounds(x: x, y: y, width: width, height: height)

        while hasOverlappingNode(candidate, in: graph) {
            x += width + Self.childHorizontalGap
            candidate = CanvasBounds(x: x, y: y, width: width, height: height)
        }
        return candidate
    }

    func sortedNodes(in graph: CanvasGraph) -> [CanvasNode] {
        graph.nodesByID.values.sorted { lhs, rhs in
            if lhs.bounds.y == rhs.bounds.y {
                return lhs.bounds.x < rhs.bounds.x
            }
            return lhs.bounds.y < rhs.bounds.y
        }
    }

    func nodeCenter(for node: CanvasNode) -> (x: Double, y: Double) {
        (
            x: node.bounds.x + (node.bounds.width / 2),
            y: node.bounds.y + (node.bounds.height / 2)
        )
    }

    func squaredDistance(
        from source: (x: Double, y: Double),
        to destination: (x: Double, y: Double)
    ) -> Double {
        let deltaX = destination.x - source.x
        let deltaY = destination.y - source.y
        return (deltaX * deltaX) + (deltaY * deltaY)
    }

    func descendantNodeIDs(of rootID: CanvasNodeID, in graph: CanvasGraph) -> Set<CanvasNodeID> {
        var visited: Set<CanvasNodeID> = []
        var queue: [CanvasNodeID] = [rootID]

        while !queue.isEmpty {
            let currentID = queue.removeFirst()
            for edge in graph.edgesByID.values where edge.relationType == .parentChild && edge.fromNodeID == currentID {
                let childID = edge.toNodeID
                guard !visited.contains(childID) else {
                    continue
                }
                visited.insert(childID)
                queue.append(childID)
            }
        }

        return visited
    }

    func parentNodeID(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasNodeID? {
        graph.edgesByID.values
            .filter { $0.relationType == .parentChild && $0.toNodeID == nodeID }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first?
            .fromNodeID
    }

    func isTopLevelParent(_ nodeID: CanvasNodeID, in graph: CanvasGraph) -> Bool {
        !graph.edgesByID.values.contains {
            $0.relationType == .parentChild && $0.toNodeID == nodeID
        }
    }

    private func firstOverlappedNode(for candidate: CanvasBounds, in nodes: [CanvasNode]) -> CanvasNode? {
        nodes.first { node in
            boundsOverlap(candidate, node.bounds)
        }
    }

    private func hasOverlappingNode(_ bounds: CanvasBounds, in graph: CanvasGraph) -> Bool {
        graph.nodesByID.values.contains { existingNode in
            boundsOverlap(bounds, existingNode.bounds)
        }
    }

    private func boundsOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds) -> Bool {
        let lhsRight = lhs.x + lhs.width
        let lhsBottom = lhs.y + lhs.height
        let rhsRight = rhs.x + rhs.width
        let rhsBottom = rhs.y + rhs.height

        return lhs.x < rhsRight
            && lhsRight > rhs.x
            && lhs.y < rhsBottom
            && lhsBottom > rhs.y
    }
}
