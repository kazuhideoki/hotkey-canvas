<<<<<<< HEAD:Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SetNodeText.swift
=======
// Background: Keyboard-first node editing needs text update commands.
// Responsibility: Handle focused-node text updates for inline editing.
>>>>>>> main:Application/UseCase/ApplyCanvasCommandsUseCase+NodeEditing.swift
import Domain

// Background: Inline editing needs a command path to mutate node text content.
// Responsibility: Update text of an existing node and normalize empty strings to nil.
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
