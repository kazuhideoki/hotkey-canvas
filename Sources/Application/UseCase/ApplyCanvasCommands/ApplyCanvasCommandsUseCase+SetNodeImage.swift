import Domain

// Background: Nodes can render an image above text and require a dedicated mutation path.
// Responsibility: Update focused-node image reference and persist measured node height.
extension ApplyCanvasCommandsUseCase {
    private static let minimumNodeHeightForImage: Double = 1

    /// Updates node image path and height, then requests relayout to keep structure and collision consistent.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - nodeID: Target node identifier.
    ///   - imagePath: Absolute image file path selected from Finder.
    ///   - nodeHeight: Measured node height from UI after image insertion.
    /// - Returns: Mutation result with relayout effects, or no-op when values are unchanged.
    /// - Throws: Propagates node update failure from CRUD service.
    func setNodeImage(
        in graph: CanvasGraph,
        nodeID: CanvasNodeID,
        imagePath: String,
        nodeHeight: Double
    ) throws -> CanvasMutationResult {
        guard let node = graph.nodesByID[nodeID] else {
            return noOpMutationResult(for: graph)
        }

        let fallbackHeight =
            if node.bounds.height.isFinite, node.bounds.height > Self.minimumNodeHeightForImage {
                node.bounds.height
            } else {
                Self.minimumNodeHeightForImage
            }
        let proposedHeight = nodeHeight.isFinite ? nodeHeight : fallbackHeight
        let normalizedHeight = max(proposedHeight, Self.minimumNodeHeightForImage)

        if node.imagePath == imagePath, node.bounds.height == normalizedHeight {
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
            imagePath: imagePath,
            bounds: updatedBounds,
            metadata: node.metadata
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
