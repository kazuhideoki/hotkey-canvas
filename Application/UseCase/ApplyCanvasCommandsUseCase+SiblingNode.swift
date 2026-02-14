import Domain
import Foundation

// Background: Sibling-node creation depends on parent edge lookup and node placement policy.
// Responsibility: Add sibling nodes under the same parent as the focused node.
extension ApplyCanvasCommandsUseCase {
    func addSiblingNode(in graph: CanvasGraph) throws -> CanvasGraph {
        guard let focusedNodeID = graph.focusedNodeID else {
            return graph
        }
        guard graph.nodesByID[focusedNodeID] != nil else {
            return graph
        }
        guard let parentID = parentNodeID(of: focusedNodeID, in: graph) else {
            return graph
        }
        guard graph.nodesByID[parentID] != nil else {
            return graph
        }

        let siblingNode = CanvasNode(
            id: CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())"),
            kind: .text,
            text: nil,
            bounds: makeAvailableNewNodeBounds(in: graph)
        )

        var graphWithSibling = try CanvasGraphCRUDService.createNode(siblingNode, in: graph)
        let edge = CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-\(UUID().uuidString.lowercased())"),
            fromNodeID: parentID,
            toNodeID: siblingNode.id,
            relationType: .parentChild
        )
        graphWithSibling = try CanvasGraphCRUDService.createEdge(edge, in: graphWithSibling)

        return CanvasGraph(
            nodesByID: graphWithSibling.nodesByID,
            edgesByID: graphWithSibling.edgesByID,
            focusedNodeID: siblingNode.id
        )
    }

    private func parentNodeID(of nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasNodeID? {
        graph.edgesByID.values
            .filter { $0.relationType == .parentChild && $0.toNodeID == nodeID }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first?
            .fromNodeID
    }
}
