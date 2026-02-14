// Background: Node editing flows need explicit commands to change focus and node text from UI interactions.
// Responsibility: Handle focused-node targeting commands for inline text editing.
import Domain

extension ApplyCanvasCommandsUseCase {
    func focusNode(in graph: CanvasGraph, nodeID: CanvasNodeID) -> CanvasGraph {
        guard graph.nodesByID[nodeID] != nil else {
            return graph
        }
        guard graph.focusedNodeID != nodeID else {
            return graph
        }
        return CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nodeID
        )
    }

    func setNodeText(in graph: CanvasGraph, nodeID: CanvasNodeID, text: String) throws -> CanvasGraph {
        guard let node = graph.nodesByID[nodeID] else {
            return graph
        }
        let normalizedText = text.isEmpty ? nil : text
        guard node.text != normalizedText else {
            return graph
        }

        let updatedNode = CanvasNode(
            id: node.id,
            kind: node.kind,
            text: normalizedText,
            bounds: node.bounds,
            metadata: node.metadata
        )
        return try CanvasGraphCRUDService.updateNode(updatedNode, in: graph)
    }
}
