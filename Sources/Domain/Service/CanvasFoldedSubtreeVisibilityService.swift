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
        let visibleFocusedNodeID = visibleFocusedNodeID(in: graph, visibleNodeIDs: visibleNodeIDs)
        let visibleFocusedElement = visibleFocusedElement(
            in: graph,
            visibleNodeIDs: visibleNodeIDs,
            visibleEdgesByID: visibleEdgesByID,
            visibleFocusedNodeID: visibleFocusedNodeID
        )
        let normalizedCollapsedRootNodeIDs = normalizedCollapsedRootNodeIDs(in: graph)
            .intersection(visibleNodeIDs)
        let visibleSelectedNodeIDs = visibleSelectedNodeIDs(
            in: graph,
            visibleNodeIDs: visibleNodeIDs,
            visibleFocusedNodeID: visibleFocusedNodeID
        )
        let visibleSelectedEdgeIDs = visibleSelectedEdgeIDs(
            in: graph,
            visibleNodesByID: visibleNodesByID,
            visibleEdgesByID: visibleEdgesByID,
            visibleFocusedNodeID: visibleFocusedNodeID,
            visibleFocusedElement: visibleFocusedElement
        )

        return CanvasGraph(
            nodesByID: visibleNodesByID,
            edgesByID: visibleEdgesByID,
            focusedNodeID: visibleFocusedNodeID,
            focusedElement: visibleFocusedElement,
            selectedNodeIDs: visibleSelectedNodeIDs,
            selectedEdgeIDs: visibleSelectedEdgeIDs,
            collapsedRootNodeIDs: normalizedCollapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }
}

extension CanvasFoldedSubtreeVisibilityService {
    fileprivate static func visibleFocusedNodeID(
        in graph: CanvasGraph,
        visibleNodeIDs: Set<CanvasNodeID>
    ) -> CanvasNodeID? {
        if let focusedNodeID = graph.focusedNodeID, visibleNodeIDs.contains(focusedNodeID) {
            return focusedNodeID
        }
        return nil
    }

    fileprivate static func visibleFocusedElement(
        in graph: CanvasGraph,
        visibleNodeIDs: Set<CanvasNodeID>,
        visibleEdgesByID: [CanvasEdgeID: CanvasEdge],
        visibleFocusedNodeID: CanvasNodeID?
    ) -> CanvasFocusedElement? {
        if let focusedElement = graph.focusedElement {
            switch focusedElement {
            case .node(let nodeID):
                return visibleNodeIDs.contains(nodeID) ? focusedElement : nil
            case .edge(let edgeFocus):
                if visibleEdgesByID[edgeFocus.edgeID] != nil {
                    return focusedElement
                }
                if let visibleFocusedNodeID {
                    return .node(visibleFocusedNodeID)
                }
                return nil
            }
        }
        if let visibleFocusedNodeID {
            return .node(visibleFocusedNodeID)
        }
        return nil
    }

    fileprivate static func visibleSelectedNodeIDs(
        in graph: CanvasGraph,
        visibleNodeIDs: Set<CanvasNodeID>,
        visibleFocusedNodeID: CanvasNodeID?
    ) -> Set<CanvasNodeID> {
        CanvasSelectionService.normalizedSelectedNodeIDs(
            from: graph.selectedNodeIDs.intersection(visibleNodeIDs),
            in: graph,
            focusedNodeID: visibleFocusedNodeID
        )
    }

    fileprivate static func visibleSelectedEdgeIDs(
        in graph: CanvasGraph,
        visibleNodesByID: [CanvasNodeID: CanvasNode],
        visibleEdgesByID: [CanvasEdgeID: CanvasEdge],
        visibleFocusedNodeID: CanvasNodeID?,
        visibleFocusedElement: CanvasFocusedElement?
    ) -> Set<CanvasEdgeID> {
        let visibilityGraph = CanvasGraph(
            nodesByID: visibleNodesByID,
            edgesByID: visibleEdgesByID,
            focusedNodeID: visibleFocusedNodeID,
            focusedElement: visibleFocusedElement
        )
        let focusedEdgeID: CanvasEdgeID? =
            if case .edge(let focus) = visibleFocusedElement {
                focus.edgeID
            } else {
                nil
            }
        return CanvasSelectionService.normalizedSelectedEdgeIDs(
            from: graph.selectedEdgeIDs.intersection(Set(visibleEdgesByID.keys)),
            in: visibilityGraph,
            focusedEdgeID: focusedEdgeID
        )
    }

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
