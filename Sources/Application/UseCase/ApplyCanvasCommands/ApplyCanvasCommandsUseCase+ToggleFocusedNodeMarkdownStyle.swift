import Domain

// Background: Node rendering can switch between plain text and markdown-styled display per node.
// Responsibility: Toggle markdown styling for the currently focused node.
extension ApplyCanvasCommandsUseCase {
    /// Toggles markdown styling for the focused node.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Mutation result with updated markdown-styling flag for the focused node.
    /// - Throws: Propagates node update failure from CRUD service.
    func toggleFocusedNodeMarkdownStyle(in graph: CanvasGraph) throws -> CanvasMutationResult {
        guard let focusedNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return noOpMutationResult(for: graph)
        }

        let updatedNode = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            attachments: focusedNode.attachments,
            bounds: focusedNode.bounds,
            metadata: focusedNode.metadata,
            markdownStyleEnabled: !focusedNode.markdownStyleEnabled
        )
        let nextGraph = try CanvasGraphCRUDService.updateNode(updatedNode, in: graph).get()
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: nextGraph != graph,
                needsTreeLayout: true,
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: focusedNodeID
        )
    }
}
