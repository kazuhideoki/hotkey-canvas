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

    func makeSiblingNodeBounds(
        in graph: CanvasGraph,
        focusedNode: CanvasNode,
        position: CanvasSiblingNodePosition,
        avoiding nodeIDs: Set<CanvasNodeID>
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

    /// Finds all node identifiers that belong to the same parent-child area as the input node.
    /// - Parameters:
    ///   - nodeID: Node used to identify the area.
    ///   - graph: Current canvas graph.
    /// - Returns: Node identifiers in the matched area, or an empty set when no area is found.
    func parentChildAreaNodeIDs(containing nodeID: CanvasNodeID, in graph: CanvasGraph) -> Set<CanvasNodeID> {
        parentChildArea(containing: nodeID, in: graph)?.nodeIDs ?? []
    }

    /// Finds a parent-child area containing the input node.
    /// - Parameters:
    ///   - nodeID: Node used to identify the area.
    ///   - graph: Current canvas graph.
    /// - Returns: Matched area, or `nil` when not found.
    func parentChildArea(containing nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasNodeArea? {
        let areas = CanvasAreaLayoutService.makeParentChildAreas(in: graph)
        return areas.first(where: { $0.nodeIDs.contains(nodeID) })
    }

    /// Resolves overlaps among parent-child areas by translating colliding areas.
    /// - Parameters:
    ///   - seedNodeID: Node identifier used to select the seed area.
    ///   - graph: Graph to resolve.
    /// - Returns: Graph with translated node bounds after area overlap resolution.
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

    /// Translates bounds by a delta on both axes.
    /// - Parameters:
    ///   - bounds: Source bounds.
    ///   - dx: Horizontal translation.
    ///   - dy: Vertical translation.
    /// - Returns: Translated bounds.
    func translate(_ bounds: CanvasBounds, dx: Double, dy: Double) -> CanvasBounds {
        CanvasBounds(
            x: bounds.x + dx,
            y: bounds.y + dy,
            width: bounds.width,
            height: bounds.height
        )
    }

    /// Returns nodes sorted by top-to-bottom and then left-to-right order.
    /// - Parameter graph: Current canvas graph.
    /// - Returns: Sorted nodes.
    func sortedNodes(in graph: CanvasGraph) -> [CanvasNode] {
        graph.nodesByID.values.sorted { lhs, rhs in
            if lhs.bounds.y == rhs.bounds.y {
                return lhs.bounds.x < rhs.bounds.x
            }
            return lhs.bounds.y < rhs.bounds.y
        }
    }

    /// Computes the geometric center of a node.
    /// - Parameter node: Node to evaluate.
    /// - Returns: Center point `(x, y)`.
    func nodeCenter(for node: CanvasNode) -> (x: Double, y: Double) {
        (
            x: node.bounds.x + (node.bounds.width / 2),
            y: node.bounds.y + (node.bounds.height / 2)
        )
    }

    /// Computes squared Euclidean distance between two points.
    /// - Parameters:
    ///   - source: Start point.
    ///   - destination: End point.
    /// - Returns: Squared distance value.
    func squaredDistance(
        from source: (x: Double, y: Double),
        to destination: (x: Double, y: Double)
    ) -> Double {
        let deltaX = destination.x - source.x
        let deltaY = destination.y - source.y
        return (deltaX * deltaX) + (deltaY * deltaY)
    }

    /// Collects descendant node identifiers reachable by parent-child edges.
    /// - Parameters:
    ///   - rootID: Root node to start traversal from.
    ///   - graph: Current canvas graph.
    /// - Returns: Descendant node identifiers excluding the root.
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

    /// Finds one parent node identifier for a child node.
    /// - Parameters:
    ///   - nodeID: Child node identifier.
    ///   - graph: Current canvas graph.
    /// - Returns: Parent node identifier when found.
    func parentNodeID(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasNodeID? {
        graph.edgesByID.values
            .filter { $0.relationType == .parentChild && $0.toNodeID == nodeID }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first?
            .fromNodeID
    }

    /// Checks whether a node has no incoming parent-child edge.
    /// - Parameters:
    ///   - nodeID: Node identifier to inspect.
    ///   - graph: Current canvas graph.
    /// - Returns: `true` when the node is a top-level parent.
    func isTopLevelParent(_ nodeID: CanvasNodeID, in graph: CanvasGraph) -> Bool {
        !graph.edgesByID.values.contains {
            $0.relationType == .parentChild && $0.toNodeID == nodeID
        }
    }

    /// Builds a deterministic collision target list for placement checks.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - nodeIDs: Node identifiers to include in collision checks.
    /// - Returns: Sorted nodes used as blockers.
    private func nodesForPlacementCollision(
        in graph: CanvasGraph,
        avoiding nodeIDs: Set<CanvasNodeID>
    ) -> [CanvasNode] {
        let sourceNodes: [CanvasNode]
        if nodeIDs.isEmpty {
            sourceNodes = []
        } else {
            sourceNodes = nodeIDs.compactMap { graph.nodesByID[$0] }
        }

        return sourceNodes.sorted { lhs, rhs in
            if lhs.bounds.y == rhs.bounds.y {
                return lhs.bounds.x < rhs.bounds.x
            }
            return lhs.bounds.y < rhs.bounds.y
        }
    }

    /// Returns the first node that overlaps with candidate bounds.
    /// - Parameters:
    ///   - candidate: Bounds being tested.
    ///   - nodes: Candidate blocker nodes.
    /// - Returns: The first overlapped node, or `nil`.
    private func firstOverlappedNode(for candidate: CanvasBounds, in nodes: [CanvasNode]) -> CanvasNode? {
        nodes.first { node in
            boundsOverlap(candidate, node.bounds)
        }
    }

    /// Determines whether bounds overlap with any node in the list.
    /// - Parameters:
    ///   - bounds: Bounds being tested.
    ///   - nodes: Candidate blocker nodes.
    /// - Returns: `true` when overlap exists.
    private func hasOverlappingNode(_ bounds: CanvasBounds, in nodes: [CanvasNode]) -> Bool {
        nodes.contains { existingNode in
            boundsOverlap(bounds, existingNode.bounds)
        }
    }
    /// Evaluates axis-aligned rectangle overlap.
    /// - Parameters:
    ///   - lhs: First bounds.
    ///   - rhs: Second bounds.
    /// - Returns: `true` when two bounds overlap.
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
