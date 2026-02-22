// Background: Keyboard-first node editing needs text update commands.
// Responsibility: Handle focused-node text updates for inline editing.
import Domain

// Background: Inline editing needs a command path to mutate node text content.
// Responsibility: Update text of an existing node, normalize empty strings to nil,
// and persist measured node height safely.
extension ApplyCanvasCommandsUseCase {
    private static let minimumNodeHeight: Double = 1

    /// Updates node text and height, then requests tree/area layout to keep structure and collision consistent.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - nodeID: Target node identifier.
    ///   - text: Edited text (empty string becomes `nil`).
    ///   - nodeHeight: Measured node height from UI.
    /// - Returns: Mutation result with relayout effects, or no-op when values are unchanged.
    /// - Throws: Propagates node update failure from CRUD service.
    func setNodeText(
        in graph: CanvasGraph,
        nodeID: CanvasNodeID,
        text: String,
        nodeHeight: Double
    ) throws -> CanvasMutationResult {
        guard let node = graph.nodesByID[nodeID] else {
            return noOpMutationResult(for: graph)
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
            return noOpMutationResult(for: graph)
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
            metadata: node.metadata,
            markdownStyleEnabled: node.markdownStyleEnabled
        )
        let nextGraph = try CanvasGraphCRUDService.updateNode(updatedNode, in: graph).get()
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: nodeID
        )
    }
}
