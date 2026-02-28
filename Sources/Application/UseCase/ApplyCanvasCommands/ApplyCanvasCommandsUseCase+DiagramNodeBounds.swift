// Background: Diagram mode keeps nodes square while allowing image attachments to expand bounds.
// Responsibility: Provide attachment-aware diagram-node side normalization shared by mutation and pipeline stages.
import Domain

extension ApplyCanvasCommandsUseCase {
    /// Normalizes diagram node side length by attachment-aware bounds.
    /// - Parameters:
    ///   - proposedSide: Candidate side length.
    /// - Returns: Clamped square side length for diagram nodes.
    static func normalizedDiagramNodeSideLength(
        proposedSide: Double
    ) -> Double {
        let minimum = CanvasDefaultNodeDistance.diagramMinNodeSide
        let maximum = CanvasDefaultNodeDistance.diagramImageMaxSide
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
            proposedSide: proposedSide
        )
        return CanvasBounds(
            x: node.bounds.x,
            y: node.bounds.y,
            width: normalizedSide,
            height: normalizedSide
        )
    }
}
