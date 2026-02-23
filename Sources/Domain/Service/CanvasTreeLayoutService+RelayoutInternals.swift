import Foundation

// Background: Tree relayout needs deterministic traversal and anchoring internals.
// Responsibility: Provide private topology, traversal, and coordinate helpers for relayout.
extension CanvasTreeLayoutService {
    private struct SubtreeLayout {
        var centerYByNodeID: [CanvasNodeID: Double]
        var minY: Double
        var maxY: Double
    }

    private struct ComponentTopology {
        let nodeIDs: Set<CanvasNodeID>
        let roots: [CanvasNodeID]
        let childrenByParentID: [CanvasNodeID: [CanvasNodeID]]
    }

    private struct XLayoutContext {
        let graph: CanvasGraph
        let childrenByParentID: [CanvasNodeID: [CanvasNodeID]]
        let horizontalSpacing: Double
    }

    private struct PositionedNodes {
        let centerYByNodeID: [CanvasNodeID: Double]
        let xByNodeID: [CanvasNodeID: Double]
        let anchoredNodeIDs: Set<CanvasNodeID>
    }

    static func makeComponents(from edges: [CanvasEdge]) -> [Set<CanvasNodeID>] {
        var adjacencyByNodeID: [CanvasNodeID: Set<CanvasNodeID>] = [:]
        for edge in edges {
            adjacencyByNodeID[edge.fromNodeID, default: []].insert(edge.toNodeID)
            adjacencyByNodeID[edge.toNodeID, default: []].insert(edge.fromNodeID)
        }

        var visited: Set<CanvasNodeID> = []
        var components: [Set<CanvasNodeID>] = []
        for nodeID in adjacencyByNodeID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard !visited.contains(nodeID) else {
                continue
            }
            components.append(
                makeComponent(
                    startNodeID: nodeID,
                    adjacencyByNodeID: adjacencyByNodeID,
                    visited: &visited
                )
            )
        }
        return components
    }

    private static func makeComponent(
        startNodeID: CanvasNodeID,
        adjacencyByNodeID: [CanvasNodeID: Set<CanvasNodeID>],
        visited: inout Set<CanvasNodeID>
    ) -> Set<CanvasNodeID> {
        var queue: [CanvasNodeID] = [startNodeID]
        var index = 0
        var componentNodeIDs: Set<CanvasNodeID> = [startNodeID]
        visited.insert(startNodeID)

        while index < queue.count {
            let currentNodeID = queue[index]
            index += 1
            let neighbors = adjacencyByNodeID[currentNodeID, default: []]
                .sorted(by: { $0.rawValue < $1.rawValue })
            for neighborNodeID in neighbors where !visited.contains(neighborNodeID) {
                visited.insert(neighborNodeID)
                componentNodeIDs.insert(neighborNodeID)
                queue.append(neighborNodeID)
            }
        }
        return componentNodeIDs
    }

    static func relayoutComponent(
        nodeIDs: Set<CanvasNodeID>,
        edges: [CanvasEdge],
        graph: CanvasGraph,
        config: LayoutConfig
    ) -> [CanvasNodeID: CanvasBounds] {
        guard let topology = makeTopology(nodeIDs: nodeIDs, edges: edges, graph: graph) else {
            return [:]
        }
        let positionedNodes = makePositionedNodes(topology: topology, graph: graph, config: config)
        return makeAnchoredBounds(topology: topology, graph: graph, positionedNodes: positionedNodes)
    }

    private static func makeTopology(
        nodeIDs: Set<CanvasNodeID>,
        edges: [CanvasEdge],
        graph: CanvasGraph
    ) -> ComponentTopology? {
        let componentNodes = nodeIDs.compactMap { graph.nodesByID[$0] }
        guard !componentNodes.isEmpty else {
            return nil
        }

        let componentNodeIDSet = Set(componentNodes.map(\.id))
        let parentEdgeByChildID = makeParentEdgeByChildID(
            nodeIDs: componentNodeIDSet,
            edges: edges
        )
        let parentByChildID = Dictionary(
            uniqueKeysWithValues: parentEdgeByChildID.map { (childNodeID, edge) in
                (childNodeID, edge.fromNodeID)
            }
        )
        let roots = makeRoots(nodes: componentNodes, parentByChildID: parentByChildID)
            .sorted(by: isNodeIDOrderedBefore(graph: graph))
        let childrenByParentID = makeChildrenByParentID(
            nodes: componentNodes,
            parentEdgeByChildID: parentEdgeByChildID,
            graph: graph
        )

        return ComponentTopology(
            nodeIDs: componentNodeIDSet,
            roots: roots,
            childrenByParentID: childrenByParentID
        )
    }

    private static func makeParentEdgeByChildID(
        nodeIDs: Set<CanvasNodeID>,
        edges: [CanvasEdge]
    ) -> [CanvasNodeID: CanvasEdge] {
        let edgeCandidates =
            edges
            .filter { nodeIDs.contains($0.fromNodeID) && nodeIDs.contains($0.toNodeID) }
            .sorted(by: isEdgeOrderedBefore)
        var parentEdgeByChildID: [CanvasNodeID: CanvasEdge] = [:]
        for edge in edgeCandidates where parentEdgeByChildID[edge.toNodeID] == nil {
            parentEdgeByChildID[edge.toNodeID] = edge
        }
        return parentEdgeByChildID
    }

    private static func makeRoots(
        nodes: [CanvasNode],
        parentByChildID: [CanvasNodeID: CanvasNodeID]
    ) -> [CanvasNodeID] {
        var roots = nodes.map(\.id).filter { parentByChildID[$0] == nil }
        if roots.isEmpty, let fallbackRootNodeID = nodes.min(by: isNodeOrderedBefore)?.id {
            roots = [fallbackRootNodeID]
        }
        return roots
    }

    private static func makeChildrenByParentID(
        nodes: [CanvasNode],
        parentEdgeByChildID: [CanvasNodeID: CanvasEdge],
        graph: CanvasGraph
    ) -> [CanvasNodeID: [CanvasNodeID]] {
        var childrenByParentID = Dictionary(
            uniqueKeysWithValues: nodes.map { ($0.id, [CanvasNodeID]()) }
        )
        for (childNodeID, edge) in parentEdgeByChildID {
            childrenByParentID[edge.fromNodeID, default: []].append(childNodeID)
        }
        for parentNodeID in childrenByParentID.keys {
            let effectiveOrderByChildID = effectiveSiblingOrderByChildID(
                parentNodeID: parentNodeID,
                parentEdgeByChildID: parentEdgeByChildID,
                graph: graph
            )
            childrenByParentID[parentNodeID]?.sort { lhs, rhs in
                let lhsOrder = effectiveOrderByChildID[lhs] ?? Int.max
                let rhsOrder = effectiveOrderByChildID[rhs] ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return isNodeIDOrderedBefore(graph: graph)(lhs, rhs)
            }
        }
        return childrenByParentID
    }

    private static func effectiveSiblingOrderByChildID(
        parentNodeID: CanvasNodeID,
        parentEdgeByChildID: [CanvasNodeID: CanvasEdge],
        graph: CanvasGraph
    ) -> [CanvasNodeID: Int] {
        let parentEdges = parentEdgeByChildID.values.filter { $0.fromNodeID == parentNodeID }
        let fallbackOrderByEdgeID = fallbackSiblingOrderByEdgeID(
            parentNodeID: parentNodeID,
            parentChildEdges: parentEdges,
            graph: graph
        )
        return Dictionary(
            uniqueKeysWithValues: parentEdges.map { edge in
                let effectiveOrder = edge.parentChildOrder ?? fallbackOrderByEdgeID[edge.id] ?? Int.max
                return (edge.toNodeID, effectiveOrder)
            }
        )
    }

    private static func makePositionedNodes(
        topology: ComponentTopology,
        graph: CanvasGraph,
        config: LayoutConfig
    ) -> PositionedNodes {
        var centerYByNodeID: [CanvasNodeID: Double] = [:]
        var xByNodeID: [CanvasNodeID: Double] = [:]
        var currentRootMinY = 0.0
        var visited: Set<CanvasNodeID> = []

        let xContext = XLayoutContext(
            graph: graph,
            childrenByParentID: topology.childrenByParentID,
            horizontalSpacing: config.horizontalSpacing
        )

        for rootNodeID in topology.roots {
            let subtreeLayout = makeSubtreeLayout(
                rootNodeID: rootNodeID,
                graph: graph,
                childrenByParentID: topology.childrenByParentID,
                verticalSpacing: config.verticalSpacing,
                visited: &visited
            )
            mergeSubtree(
                subtreeLayout,
                shiftY: currentRootMinY - subtreeLayout.minY,
                centerYByNodeID: &centerYByNodeID
            )
            assignX(nodeID: rootNodeID, x: 0, context: xContext, xByNodeID: &xByNodeID)
            currentRootMinY += (subtreeLayout.maxY - subtreeLayout.minY) + config.rootSpacing
        }

        let anchoredNodeIDs = Set(centerYByNodeID.keys)
        fillUnvisitedNodes(
            nodeIDs: topology.nodeIDs,
            graph: graph,
            centerYByNodeID: &centerYByNodeID,
            xByNodeID: &xByNodeID
        )
        return PositionedNodes(
            centerYByNodeID: centerYByNodeID,
            xByNodeID: xByNodeID,
            anchoredNodeIDs: anchoredNodeIDs
        )
    }

    private static func mergeSubtree(
        _ subtreeLayout: SubtreeLayout,
        shiftY: Double,
        centerYByNodeID: inout [CanvasNodeID: Double]
    ) {
        for (nodeID, centerY) in subtreeLayout.centerYByNodeID {
            centerYByNodeID[nodeID] = centerY + shiftY
        }
    }

    private static func fillUnvisitedNodes(
        nodeIDs: Set<CanvasNodeID>,
        graph: CanvasGraph,
        centerYByNodeID: inout [CanvasNodeID: Double],
        xByNodeID: inout [CanvasNodeID: Double]
    ) {
        for nodeID in nodeIDs where centerYByNodeID[nodeID] == nil {
            guard let node = graph.nodesByID[nodeID] else {
                continue
            }
            centerYByNodeID[nodeID] = node.bounds.y + (node.bounds.height / 2)
            xByNodeID[nodeID] = node.bounds.x
        }
    }

    private static func makeAnchoredBounds(
        topology: ComponentTopology,
        graph: CanvasGraph,
        positionedNodes: PositionedNodes
    ) -> [CanvasNodeID: CanvasBounds] {
        guard let anchorRootNodeID = topology.roots.first, let anchorNode = graph.nodesByID[anchorRootNodeID] else {
            return [:]
        }

        let anchorCenterY = anchorNode.bounds.y + (anchorNode.bounds.height / 2)
        let anchorNewCenterY = positionedNodes.centerYByNodeID[anchorRootNodeID] ?? anchorCenterY
        let shiftY = anchorCenterY - anchorNewCenterY
        let anchorNewX = positionedNodes.xByNodeID[anchorRootNodeID] ?? 0
        let shiftX = anchorNode.bounds.x - anchorNewX

        var updatedBoundsByNodeID: [CanvasNodeID: CanvasBounds] = [:]
        for nodeID in topology.nodeIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let node = graph.nodesByID[nodeID] else {
                continue
            }
            // Nodes filled as "unvisited" already use absolute graph coordinates.
            // Re-applying anchor shift to them would introduce unintended jumps.
            let shouldApplyAnchorShift = positionedNodes.anchoredNodeIDs.contains(nodeID)
            let centerYBase =
                positionedNodes.centerYByNodeID[nodeID] ?? (node.bounds.y + (node.bounds.height / 2))
            let xBase = positionedNodes.xByNodeID[nodeID] ?? node.bounds.x
            let centerY = shouldApplyAnchorShift ? (centerYBase + shiftY) : centerYBase
            let x = shouldApplyAnchorShift ? (xBase + shiftX) : xBase
            updatedBoundsByNodeID[nodeID] = CanvasBounds(
                x: x,
                y: centerY - (node.bounds.height / 2),
                width: node.bounds.width,
                height: node.bounds.height
            )
        }
        return updatedBoundsByNodeID
    }

    private static func makeSubtreeLayout(
        rootNodeID: CanvasNodeID,
        graph: CanvasGraph,
        childrenByParentID: [CanvasNodeID: [CanvasNodeID]],
        verticalSpacing: Double,
        visited: inout Set<CanvasNodeID>
    ) -> SubtreeLayout {
        guard let rootNode = graph.nodesByID[rootNodeID] else {
            return SubtreeLayout(centerYByNodeID: [:], minY: 0, maxY: 0)
        }
        if visited.contains(rootNodeID) {
            return leafLayout(nodeID: rootNodeID, height: rootNode.bounds.height)
        }
        visited.insert(rootNodeID)

        let childNodeIDs = childrenByParentID[rootNodeID] ?? []
        guard !childNodeIDs.isEmpty else {
            return leafLayout(nodeID: rootNodeID, height: rootNode.bounds.height)
        }

        var centerYByNodeID: [CanvasNodeID: Double] = [:]
        var currentMinY = 0.0
        var stackedMaxY = 0.0

        for childNodeID in childNodeIDs {
            let childLayout = makeSubtreeLayout(
                rootNodeID: childNodeID,
                graph: graph,
                childrenByParentID: childrenByParentID,
                verticalSpacing: verticalSpacing,
                visited: &visited
            )
            mergeSubtree(childLayout, shiftY: currentMinY - childLayout.minY, centerYByNodeID: &centerYByNodeID)
            let childHeight = childLayout.maxY - childLayout.minY
            currentMinY += childHeight + verticalSpacing
            stackedMaxY = currentMinY - verticalSpacing
        }

        let childrenCenterY = stackedMaxY / 2
        centerYByNodeID[rootNodeID] = childrenCenterY
        let rootHalfHeight = rootNode.bounds.height / 2
        let rootMinY = childrenCenterY - rootHalfHeight
        let rootMaxY = childrenCenterY + rootHalfHeight

        return SubtreeLayout(
            centerYByNodeID: centerYByNodeID,
            minY: min(0, rootMinY),
            maxY: max(stackedMaxY, rootMaxY)
        )
    }

    private static func leafLayout(nodeID: CanvasNodeID, height: Double) -> SubtreeLayout {
        let halfHeight = height / 2
        return SubtreeLayout(
            centerYByNodeID: [nodeID: 0],
            minY: -halfHeight,
            maxY: halfHeight
        )
    }

    private static func assignX(
        nodeID: CanvasNodeID,
        x: Double,
        context: XLayoutContext,
        xByNodeID: inout [CanvasNodeID: Double]
    ) {
        guard xByNodeID[nodeID] == nil else {
            return
        }
        xByNodeID[nodeID] = x
        guard let parentNode = context.graph.nodesByID[nodeID] else {
            return
        }

        let childX = x + parentNode.bounds.width + context.horizontalSpacing
        for childNodeID in context.childrenByParentID[nodeID] ?? [] {
            assignX(
                nodeID: childNodeID,
                x: childX,
                context: context,
                xByNodeID: &xByNodeID
            )
        }
    }
}
