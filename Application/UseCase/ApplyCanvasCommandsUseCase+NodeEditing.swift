// Background: Keyboard-first node editing needs text update commands.
// Responsibility: Handle focused-node text updates for inline editing.
import Domain

extension ApplyCanvasCommandsUseCase {
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
