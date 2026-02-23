import Foundation

// Background: Tree relayout needs stable ordering and edge filtering to keep results deterministic.
// Responsibility: Provide ordering helpers shared by tree relayout internals.
extension CanvasTreeLayoutService {
    static func validParentChildEdges(in graph: CanvasGraph) -> [CanvasEdge] {
        graph.edgesByID.values.filter { edge in
            edge.relationType == .parentChild
                && graph.nodesByID[edge.fromNodeID] != nil
                && graph.nodesByID[edge.toNodeID] != nil
        }
    }

    static func isNodeOrderedBefore(_ lhs: CanvasNode, _ rhs: CanvasNode) -> Bool {
        if lhs.bounds.y != rhs.bounds.y {
            return lhs.bounds.y < rhs.bounds.y
        }
        if lhs.bounds.x != rhs.bounds.x {
            return lhs.bounds.x < rhs.bounds.x
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    static func isNodeIDOrderedBefore(graph: CanvasGraph) -> (CanvasNodeID, CanvasNodeID) -> Bool {
        { lhs, rhs in
            guard let lhsNode = graph.nodesByID[lhs], let rhsNode = graph.nodesByID[rhs] else {
                return lhs.rawValue < rhs.rawValue
            }
            return isNodeOrderedBefore(lhsNode, rhsNode)
        }
    }

    static func isEdgeOrderedBefore(_ lhs: CanvasEdge, _ rhs: CanvasEdge) -> Bool {
        if lhs.toNodeID != rhs.toNodeID {
            return lhs.toNodeID.rawValue < rhs.toNodeID.rawValue
        }
        if lhs.fromNodeID != rhs.fromNodeID {
            return lhs.fromNodeID.rawValue < rhs.fromNodeID.rawValue
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    static func fallbackSiblingOrderByEdgeID(
        parentNodeID: CanvasNodeID,
        parentChildEdges: [CanvasEdge],
        graph: CanvasGraph
    ) -> [CanvasEdgeID: Int] {
        let sortedEdges =
            parentChildEdges
            .filter { $0.fromNodeID == parentNodeID }
            .sorted { lhs, rhs in
                guard
                    let lhsNode = graph.nodesByID[lhs.toNodeID],
                    let rhsNode = graph.nodesByID[rhs.toNodeID]
                else {
                    return lhs.id.rawValue < rhs.id.rawValue
                }
                if isNodeOrderedBefore(lhsNode, rhsNode) {
                    return true
                }
                if isNodeOrderedBefore(rhsNode, lhsNode) {
                    return false
                }
                return lhs.id.rawValue < rhs.id.rawValue
            }
        return Dictionary(
            uniqueKeysWithValues: sortedEdges.enumerated().map { (index, edge) in
                (edge.id, index)
            }
        )
    }
}
