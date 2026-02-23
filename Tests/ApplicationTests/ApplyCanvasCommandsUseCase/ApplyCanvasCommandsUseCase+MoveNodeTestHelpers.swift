import Domain

// Background: Move-node tests repeatedly assert parent-child relations and sibling order.
// Responsibility: Provide reusable graph-inspection helpers for move-node test suites.
func multiSelectionHasParentChildEdge(
    from parentID: CanvasNodeID,
    to childID: CanvasNodeID,
    in graph: CanvasGraph
) -> Bool {
    graph.edgesByID.values.contains {
        $0.relationType == .parentChild
            && $0.fromNodeID == parentID
            && $0.toNodeID == childID
    }
}

func multiSelectionParentNodeID(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasNodeID? {
    graph.edgesByID.values
        .filter {
            $0.relationType == .parentChild
                && $0.toNodeID == nodeID
        }
        .sorted { $0.id.rawValue < $1.id.rawValue }
        .first?
        .fromNodeID
}

func multiSelectionChildNodeIDs(of parentID: CanvasNodeID, in graph: CanvasGraph) -> [CanvasNodeID] {
    graph.edgesByID.values
        .filter {
            $0.relationType == .parentChild
                && $0.fromNodeID == parentID
        }
        .compactMap { edge in
            graph.nodesByID[edge.toNodeID]
        }
        .sorted { lhs, rhs in
            if lhs.bounds.y == rhs.bounds.y {
                return lhs.id.rawValue < rhs.id.rawValue
            }
            return lhs.bounds.y < rhs.bounds.y
        }
        .map(\.id)
}
