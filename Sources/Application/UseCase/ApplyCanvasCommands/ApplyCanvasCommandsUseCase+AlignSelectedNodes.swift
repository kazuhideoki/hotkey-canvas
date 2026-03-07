import Domain

// Background: Diagram editing needs a deterministic way to straighten multi-selected nodes without changing order.
// Responsibility: Align selected diagram nodes to the focused node on one axis while preserving the orthogonal axis.
extension ApplyCanvasCommandsUseCase {
    /// Aligns selected diagram nodes along the requested axis using the focused node as the anchor.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - axis: Axis to normalize across selected nodes.
    ///   - areaMode: Editing mode of the focused area.
    /// - Returns: Mutation result when at least one selected node changes.
    /// - Throws: Propagates node update failures.
    func alignSelectedNodes(
        in graph: CanvasGraph,
        axis: CanvasNodeAlignmentAxis,
        areaMode: CanvasEditingMode
    ) throws -> CanvasMutationResult {
        guard areaMode == .diagram else {
            return noOpMutationResult(for: graph)
        }
        guard
            let focusedNodeID = graph.focusedNodeID,
            let focusedNode = graph.nodesByID[focusedNodeID]
        else {
            return noOpMutationResult(for: graph)
        }
        let normalizedFocusedBounds = Self.normalizedDiagramNodeBounds(
            for: focusedNode,
            proposedSide: focusedNode.bounds.width
        )

        let selectedNodeIDs = selectedNodeIDsInFocusedArea(in: graph)
        guard selectedNodeIDs.count > 1 else {
            return noOpMutationResult(for: graph)
        }

        let anchorCenter = (
            x: normalizedFocusedBounds.x + (normalizedFocusedBounds.width / 2),
            y: normalizedFocusedBounds.y + (normalizedFocusedBounds.height / 2)
        )
        var nextGraph = graph
        var didMutate = false

        for nodeID in selectedNodeIDs {
            guard let node = nextGraph.nodesByID[nodeID] else {
                continue
            }
            let alignedBounds = alignedDiagramBounds(
                for: node,
                axis: axis,
                anchorCenterX: anchorCenter.x,
                anchorCenterY: anchorCenter.y
            )

            guard alignedBounds != node.bounds else {
                continue
            }

            let updatedNode = CanvasNode(
                id: node.id,
                kind: node.kind,
                text: node.text,
                attachments: node.attachments,
                bounds: alignedBounds,
                metadata: node.metadata,
                markdownStyleEnabled: node.markdownStyleEnabled
            )
            nextGraph = try CanvasGraphCRUDService.updateNode(updatedNode, in: nextGraph).get()
            didMutate = true
        }

        guard didMutate else {
            return noOpMutationResult(for: graph)
        }

        return alignmentMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            axis: axis,
            focusedNodeID: focusedNodeID,
            selectedNodeIDs: selectedNodeIDs
        )
    }

    private func alignmentMutationResult(
        graphBeforeMutation: CanvasGraph,
        graphAfterMutation: CanvasGraph,
        axis: CanvasNodeAlignmentAxis,
        focusedNodeID: CanvasNodeID,
        selectedNodeIDs: [CanvasNodeID]
    ) -> CanvasMutationResult {
        return CanvasMutationResult(
            graphBeforeMutation: graphBeforeMutation,
            graphAfterMutation: graphAfterMutation,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: focusedNodeID,
            diagramAlignmentConstraint: CanvasDiagramAlignmentConstraint(
                axis: axis,
                fixedNodeID: focusedNodeID,
                targetNodeIDs: Set(selectedNodeIDs).union([focusedNodeID])
            )
        )
    }

    private func alignedDiagramBounds(
        for node: CanvasNode,
        axis: CanvasNodeAlignmentAxis,
        anchorCenterX: Double,
        anchorCenterY: Double
    ) -> CanvasBounds {
        let normalizedNodeBounds = Self.normalizedDiagramNodeBounds(
            for: node,
            proposedSide: node.bounds.width
        )
        switch axis {
        case .horizontal:
            return CanvasBounds(
                x: normalizedNodeBounds.x,
                y: anchorCenterY - (normalizedNodeBounds.height / 2),
                width: normalizedNodeBounds.width,
                height: normalizedNodeBounds.height
            )
        case .vertical:
            return CanvasBounds(
                x: anchorCenterX - (normalizedNodeBounds.width / 2),
                y: normalizedNodeBounds.y,
                width: normalizedNodeBounds.width,
                height: normalizedNodeBounds.height
            )
        }
    }
}
