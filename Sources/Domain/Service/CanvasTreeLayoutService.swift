import Foundation

// Background: Parent-child editing requires deterministic full-tree relayout after structure or size changes.
// Responsibility: Recompute parent-child tree node bounds symmetrically and without sibling overlap.
/// Pure domain service that recalculates parent-child tree positions.
public enum CanvasTreeLayoutService {
    private struct LayoutConfig {
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

    private static func makeComponents(from edges: [CanvasEdge]) -> [Set<CanvasNodeID>] {
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

    private static func relayoutComponent(
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
        let parentByChildID = makeParentByChildID(
            nodeIDs: componentNodeIDSet,
            edges: edges
        )
        let roots = makeRoots(nodes: componentNodes, parentByChildID: parentByChildID)
            .sorted(by: isNodeIDOrderedBefore(graph: graph))
        let childrenByParentID = makeChildrenByParentID(
            nodes: componentNodes,
            parentByChildID: parentByChildID,
            graph: graph
        )

        return ComponentTopology(
            nodeIDs: componentNodeIDSet,
            roots: roots,
            childrenByParentID: childrenByParentID
        )
    }

    private static func makeParentByChildID(
        nodeIDs: Set<CanvasNodeID>,
        edges: [CanvasEdge]
    ) -> [CanvasNodeID: CanvasNodeID] {
        let edgeCandidates =
            edges
            .filter { nodeIDs.contains($0.fromNodeID) && nodeIDs.contains($0.toNodeID) }
            .sorted(by: isEdgeOrderedBefore)
        var parentByChildID: [CanvasNodeID: CanvasNodeID] = [:]
        for edge in edgeCandidates where parentByChildID[edge.toNodeID] == nil {
            parentByChildID[edge.toNodeID] = edge.fromNodeID
        }
        return parentByChildID
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
        parentByChildID: [CanvasNodeID: CanvasNodeID],
        graph: CanvasGraph
    ) -> [CanvasNodeID: [CanvasNodeID]] {
        var childrenByParentID = Dictionary(
            uniqueKeysWithValues: nodes.map { ($0.id, [CanvasNodeID]()) }
        )
        for (childNodeID, parentNodeID) in parentByChildID {
            childrenByParentID[parentNodeID, default: []].append(childNodeID)
        }
        for parentNodeID in childrenByParentID.keys {
            childrenByParentID[parentNodeID]?.sort(by: isNodeIDOrderedBefore(graph: graph))
        }
        return childrenByParentID
    }

    private static func makePositionedNodes(
        topology: ComponentTopology,
        graph: CanvasGraph,
        config: LayoutConfig
    ) -> (
        centerYByNodeID: [CanvasNodeID: Double],
        xByNodeID: [CanvasNodeID: Double],
        anchoredNodeIDs: Set<CanvasNodeID>
    ) {
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
        return (centerYByNodeID, xByNodeID, anchoredNodeIDs)
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

    /// Converts positioned node centers to final bounds anchored to the selected root.
    /// - Parameters:
    ///   - topology: Component topology containing node IDs and roots.
    ///   - graph: Source graph snapshot.
    ///   - positionedNodes: Layout positions and membership of nodes affected by root anchoring.
    /// - Returns: Final bounds keyed by node identifier.
    private static func makeAnchoredBounds(
        topology: ComponentTopology,
        graph: CanvasGraph,
        positionedNodes: (
            centerYByNodeID: [CanvasNodeID: Double],
            xByNodeID: [CanvasNodeID: Double],
            anchoredNodeIDs: Set<CanvasNodeID>
        )
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
