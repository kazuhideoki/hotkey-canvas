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
    ///   - nodeWidth: Measured node width from UI after attachment update.
    ///   - nodeHeight: Measured node height from UI after attachment update.
    /// - Returns: Mutation result with relayout effects, or no-op when values are unchanged.
    /// - Throws: Propagates node update failure from CRUD service.
    func upsertNodeAttachment(
        in graph: CanvasGraph,
        nodeID: CanvasNodeID,
        attachment: CanvasAttachment,
        nodeWidth: Double,
        nodeHeight: Double
    ) throws -> CanvasMutationResult {
        guard let node = graph.nodesByID[nodeID] else {
            return noOpMutationResult(for: graph)
        }

        let updatedAttachments = upsertAttachment(attachment, in: node.attachments)
        let normalizedBounds = try normalizedAttachmentBounds(
            for: node,
            graph: graph,
            updatedAttachments: updatedAttachments,
            nodeWidth: nodeWidth,
            nodeHeight: nodeHeight
        )

        if node.attachments == updatedAttachments, node.bounds == normalizedBounds {
            return noOpMutationResult(for: graph)
        }

        let updatedNode = CanvasNode(
            id: node.id,
            kind: node.kind,
            text: node.text,
            attachments: updatedAttachments,
            bounds: normalizedBounds,
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

    private func normalizedAttachmentBounds(
        for node: CanvasNode,
        graph: CanvasGraph,
        updatedAttachments: [CanvasAttachment],
        nodeWidth: Double,
        nodeHeight: Double
    ) throws -> CanvasBounds {
        let normalizedHeight = normalizedAttachmentMeasurement(
            measuredValue: nodeHeight,
            currentValue: node.bounds.height
        )
        let normalizedWidth = normalizedAttachmentMeasurement(
            measuredValue: nodeWidth,
            currentValue: node.bounds.width
        )
        let areaID = try CanvasAreaMembershipService.areaID(containing: node.id, in: graph).get()
        let area = try CanvasAreaMembershipService.area(withID: areaID, in: graph).get()
        guard area.editingMode == .diagram else {
            return CanvasBounds(
                x: node.bounds.x,
                y: node.bounds.y,
                width: node.bounds.width,
                height: normalizedHeight
            )
        }
        let updatedNodeForBounds = CanvasNode(
            id: node.id,
            kind: node.kind,
            text: node.text,
            attachments: updatedAttachments,
            bounds: node.bounds,
            metadata: node.metadata,
            markdownStyleEnabled: node.markdownStyleEnabled
        )
        return Self.normalizedDiagramNodeBounds(
            for: updatedNodeForBounds,
            proposedSide: normalizedWidth
        )
    }

    private func normalizedAttachmentMeasurement(
        measuredValue: Double,
        currentValue: Double
    ) -> Double {
        let fallbackValue =
            if currentValue.isFinite, currentValue > Self.minimumNodeHeightForAttachment {
                currentValue
            } else {
                Self.minimumNodeHeightForAttachment
            }
        let proposedValue = measuredValue.isFinite ? measuredValue : fallbackValue
        return max(proposedValue, Self.minimumNodeHeightForAttachment)
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
