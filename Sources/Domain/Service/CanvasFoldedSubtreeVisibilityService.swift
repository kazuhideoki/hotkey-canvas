// Background: Subtree folding keeps descendants in graph state while hiding them from interaction and rendering.
// Responsibility: Compute collapsed subtree visibility and normalization rules from pure graph data.
/// Pure domain service for folded-subtree visibility calculations.
public enum CanvasFoldedSubtreeVisibilityService {
    /// Returns descendant node identifiers of a root following parent-child edges.
    /// - Parameters:
    ///   - rootNodeID: Root node identifier.
    ///   - graph: Source graph snapshot.
    /// - Returns: Descendant node identifiers excluding the root.
    public static func descendantNodeIDs(
        of rootNodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> Set<CanvasNodeID> {
        let childNodeIDsByParentID = makeChildNodeIDsByParentID(in: graph)
        var descendants: Set<CanvasNodeID> = []
        var queue: [CanvasNodeID] = [rootNodeID]

        while !queue.isEmpty {
            let parentID = queue.removeFirst()
            let childNodeIDs = childNodeIDsByParentID[parentID] ?? []

            for childNodeID in childNodeIDs where descendants.insert(childNodeID).inserted {
                queue.append(childNodeID)
            }
        }

        return descendants
    }

    /// Returns whether the input node has at least one descendant.
    /// - Parameters:
    ///   - nodeID: Root node identifier.
    ///   - graph: Source graph snapshot.
    /// - Returns: `true` when at least one descendant exists.
    public static func hasDescendants(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> Bool {
        !descendantNodeIDs(of: nodeID, in: graph).isEmpty
    }

    /// Returns collapsed root identifiers normalized against graph validity.
    /// - Parameter graph: Source graph snapshot.
    /// - Returns: Existing node identifiers that still have descendants.
    public static func normalizedCollapsedRootNodeIDs(in graph: CanvasGraph) -> Set<CanvasNodeID> {
        graph.collapsedRootNodeIDs.filter { rootNodeID in
            graph.nodesByID[rootNodeID] != nil
                && hasDescendants(of: rootNodeID, in: graph)
        }
    }

    /// Returns hidden descendant node identifiers produced by collapsed roots.
    /// - Parameter graph: Source graph snapshot.
    /// - Returns: Node identifiers that should be hidden.
    public static func hiddenNodeIDs(in graph: CanvasGraph) -> Set<CanvasNodeID> {
        normalizedCollapsedRootNodeIDs(in: graph).reduce(into: Set<CanvasNodeID>()) { hidden, rootNodeID in
            hidden.formUnion(descendantNodeIDs(of: rootNodeID, in: graph))
        }
    }

    /// Returns visible node identifiers.
    /// - Parameter graph: Source graph snapshot.
    /// - Returns: Node identifiers not hidden by collapsed roots.
    public static func visibleNodeIDs(in graph: CanvasGraph) -> Set<CanvasNodeID> {
        let hiddenNodeIDs = hiddenNodeIDs(in: graph)
        let allNodeIDs = Set(graph.nodesByID.keys)
        return allNodeIDs.subtracting(hiddenNodeIDs)
    }

    /// Returns a graph snapshot containing visible nodes and edges only.
    /// - Parameter graph: Source graph snapshot.
    /// - Returns: Visible-only graph used by focus/navigation logic.
    public static func visibleGraph(from graph: CanvasGraph) -> CanvasGraph {
        let visibleNodeIDs = visibleNodeIDs(in: graph)
        let visibleNodesByID = graph.nodesByID.filter { visibleNodeIDs.contains($0.key) }
        let visibleEdgesByID = graph.edgesByID.filter { _, edge in
            visibleNodeIDs.contains(edge.fromNodeID) && visibleNodeIDs.contains(edge.toNodeID)
        }
        let visibleFocusedNodeID: CanvasNodeID? =
            if let focusedNodeID = graph.focusedNodeID, visibleNodeIDs.contains(focusedNodeID) {
                focusedNodeID
            } else {
                nil
            }
        let normalizedCollapsedRootNodeIDs = normalizedCollapsedRootNodeIDs(in: graph)
            .intersection(visibleNodeIDs)
        let visibleSelectedNodeIDs = CanvasSelectionService.normalizedSelectedNodeIDs(
            from: graph.selectedNodeIDs.intersection(visibleNodeIDs),
            in: graph,
            focusedNodeID: visibleFocusedNodeID
        )

        return CanvasGraph(
            nodesByID: visibleNodesByID,
            edgesByID: visibleEdgesByID,
            focusedNodeID: visibleFocusedNodeID,
            selectedNodeIDs: visibleSelectedNodeIDs,
            collapsedRootNodeIDs: normalizedCollapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }
}

extension CanvasFoldedSubtreeVisibilityService {
    /// Builds deterministic parent-to-children adjacency for parent-child edges.
    /// - Parameter graph: Source graph snapshot.
    /// - Returns: Child identifiers keyed by parent identifier.
    fileprivate static func makeChildNodeIDsByParentID(in graph: CanvasGraph) -> [CanvasNodeID: [CanvasNodeID]] {
        var childNodeIDsByParentID: [CanvasNodeID: [CanvasNodeID]] = [:]

        for edge in graph.edgesByID.values
        where edge.relationType == .parentChild
            && graph.nodesByID[edge.fromNodeID] != nil
            && graph.nodesByID[edge.toNodeID] != nil
        {
            childNodeIDsByParentID[edge.fromNodeID, default: []].append(edge.toNodeID)
        }

        for parentNodeID in childNodeIDsByParentID.keys {
            childNodeIDsByParentID[parentNodeID]?.sort { lhs, rhs in
                lhs.rawValue < rhs.rawValue
            }
        }

        return childNodeIDsByParentID
    }
}
