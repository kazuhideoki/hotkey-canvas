// Background: Keyboard-first node editing needs text update commands.
// Responsibility: Handle focused-node text updates for inline editing.
import Domain

// Background: Inline editing needs a command path to mutate node text content.
// Responsibility: Update text of an existing node and normalize empty strings to nil.
extension ApplyCanvasCommandsUseCase {
    private static let minimumNodeHeight: Double = 1

    func setNodeText(
        in graph: CanvasGraph,
        nodeID: CanvasNodeID,
        text: String,
        nodeHeight: Double
    ) throws -> CanvasGraph {
        guard let node = graph.nodesByID[nodeID] else {
            return graph
        }

        let normalizedText = text.isEmpty ? nil : text
        let fallbackHeight =
            if node.bounds.height.isFinite, node.bounds.height > Self.minimumNodeHeight {
                node.bounds.height
            } else {
                Self.minimumNodeHeight
            }
        let proposedHeight = nodeHeight.isFinite ? nodeHeight : fallbackHeight
        let normalizedHeight = max(proposedHeight, Self.minimumNodeHeight)
        if node.text == normalizedText, node.bounds.height == normalizedHeight {
            return graph
        }

        let updatedBounds = CanvasBounds(
            x: node.bounds.x,
            y: node.bounds.y,
            width: node.bounds.width,
            height: normalizedHeight
        )

        let updatedNode = CanvasNode(
            id: node.id,
            kind: node.kind,
            text: normalizedText,
            bounds: updatedBounds,
            metadata: node.metadata
        )
        return try CanvasGraphCRUDService.updateNode(updatedNode, in: graph)
    }
}
