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
    private static let areaCollisionSpacing: Double = 32

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

        return CanvasBounds(
            x: startX,
            y: startY,
            width: Self.newNodeWidth,
            height: Self.newNodeHeight
        )
    }

    func calculateChildBounds(for parentNode: CanvasNode, in _: CanvasGraph) -> CanvasBounds {
        let width = parentNode.bounds.width
        let height = parentNode.bounds.height
        let y = parentNode.bounds.y

        return CanvasBounds(
            x: parentNode.bounds.x + parentNode.bounds.width + Self.childHorizontalGap,
            y: y,
            width: width,
            height: height
        )
    }

    func resolveAreaOverlaps(around seedNodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasGraph {
        let areas = CanvasAreaLayoutService.makeParentChildAreas(in: graph)
        guard let seedArea = areas.first(where: { $0.nodeIDs.contains(seedNodeID) }) else {
            return graph
        }

        let translationsByAreaID = CanvasAreaLayoutService.resolveOverlaps(
            areas: areas,
            seedAreaID: seedArea.id,
            minimumSpacing: Self.areaCollisionSpacing
        )
        guard !translationsByAreaID.isEmpty else {
            return graph
        }

        let areasByID = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, $0) })
        var nodesByID = graph.nodesByID

        for areaID in translationsByAreaID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let translation = translationsByAreaID[areaID] else {
                continue
            }
            guard let area = areasByID[areaID] else {
                continue
            }

            for nodeID in area.nodeIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let node = nodesByID[nodeID] else {
                    continue
                }
                nodesByID[nodeID] = CanvasNode(
                    id: node.id,
                    kind: node.kind,
                    text: node.text,
                    bounds: translate(node.bounds, dx: translation.dx, dy: translation.dy),
                    metadata: node.metadata
                )
            }
        }

        return CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID
        )
    }

    func translate(_ bounds: CanvasBounds, dx: Double, dy: Double) -> CanvasBounds {
        CanvasBounds(
            x: bounds.x + dx,
            y: bounds.y + dy,
            width: bounds.width,
            height: bounds.height
        )
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
}
