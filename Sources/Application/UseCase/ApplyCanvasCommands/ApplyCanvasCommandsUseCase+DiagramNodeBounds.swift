// Background: Diagram mode keeps nodes square while allowing image attachments to expand bounds.
// Responsibility: Provide attachment-aware diagram-node side normalization shared by mutation and pipeline stages.
import Domain

extension ApplyCanvasCommandsUseCase {
    /// Normalizes diagram node side length by attachment-aware bounds.
    /// - Parameters:
    ///   - proposedSide: Candidate side length.
    ///   - hasImageAttachment: Whether node has at least one image attachment.
    /// - Returns: Clamped square side length for diagram nodes.
    static func normalizedDiagramNodeSideLength(
        proposedSide: Double,
        hasImageAttachment: Bool
    ) -> Double {
        let minimum = CanvasDefaultNodeDistance.diagramNodeSide
        let maximum =
            if hasImageAttachment {
                CanvasDefaultNodeDistance.diagramImageMaxSide
            } else {
                CanvasDefaultNodeDistance.diagramNodeSide
            }
        let finiteProposedSide =
            if proposedSide.isFinite {
                proposedSide
            } else {
                minimum
            }
        return max(min(finiteProposedSide, maximum), minimum)
    }

    /// Resolves normalized square bounds for diagram nodes.
    /// - Parameters:
    ///   - node: Source node carrying position and attachments.
    ///   - proposedSide: Candidate side length.
    /// - Returns: Diagram-safe square bounds preserving node origin.
    static func normalizedDiagramNodeBounds(
        for node: CanvasNode,
        proposedSide: Double
    ) -> CanvasBounds {
        let normalizedSide = normalizedDiagramNodeSideLength(
            proposedSide: proposedSide,
            hasImageAttachment: node.primaryImageAttachmentFilePath != nil
        )
        return CanvasBounds(
            x: node.bounds.x,
            y: node.bounds.y,
            width: normalizedSide,
            height: normalizedSide
        )
    }
}
