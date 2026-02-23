import Domain

// Background: Nodes support non-text attachments that can change visual height and layout.
// Responsibility: Upsert one node attachment and persist measured node height.
extension ApplyCanvasCommandsUseCase {
    private static let minimumNodeHeightForAttachment: Double = 1

    /// Upserts one node attachment and height, then requests relayout to keep structure and collision consistent.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - nodeID: Target node identifier.
    ///   - attachment: Attachment payload selected from UI.
    ///   - nodeHeight: Measured node height from UI after attachment update.
    /// - Returns: Mutation result with relayout effects, or no-op when values are unchanged.
    /// - Throws: Propagates node update failure from CRUD service.
    func upsertNodeAttachment(
        in graph: CanvasGraph,
        nodeID: CanvasNodeID,
        attachment: CanvasAttachment,
        nodeHeight: Double
    ) throws -> CanvasMutationResult {
        guard let node = graph.nodesByID[nodeID] else {
            return noOpMutationResult(for: graph)
        }

        let fallbackHeight =
            if node.bounds.height.isFinite, node.bounds.height > Self.minimumNodeHeightForAttachment {
                node.bounds.height
            } else {
                Self.minimumNodeHeightForAttachment
            }
        let proposedHeight = nodeHeight.isFinite ? nodeHeight : fallbackHeight
        let normalizedHeight = max(proposedHeight, Self.minimumNodeHeightForAttachment)
        let updatedAttachments = upsertAttachment(attachment, in: node.attachments)

        if node.attachments == updatedAttachments, node.bounds.height == normalizedHeight {
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
            text: node.text,
            attachments: updatedAttachments,
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

    private func upsertAttachment(
        _ attachment: CanvasAttachment,
        in attachments: [CanvasAttachment]
    ) -> [CanvasAttachment] {
        if let exactIDIndex = attachments.firstIndex(where: { $0.id == attachment.id }) {
            var nextAttachments = attachments
            nextAttachments[exactIDIndex] = attachment
            return nextAttachments
        }
        // Keep current behavior for image insertion: one image per placement.
        if let existingImageIndex = attachments.firstIndex(where: {
            $0.placement == attachment.placement
                && $0.imageFilePath != nil
                && attachment.imageFilePath != nil
        }) {
            var nextAttachments = attachments
            nextAttachments[existingImageIndex] = attachment
            return nextAttachments
        }
        return attachments + [attachment]
    }
}
