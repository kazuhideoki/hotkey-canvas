// Background: Diagram alignment commands need declarative post-processing after mutation.
// Responsibility: Describe overlap-resolution constraints for aligned diagram nodes.
import Domain

/// Constraint used by the pipeline to preserve a diagram alignment axis during overlap resolution.
struct CanvasDiagramAlignmentConstraint: Equatable, Sendable {
    let axis: CanvasNodeAlignmentAxis
    let fixedNodeID: CanvasNodeID
    let targetNodeIDs: Set<CanvasNodeID>
    let minimumSpacing: Double

    init(
        axis: CanvasNodeAlignmentAxis,
        fixedNodeID: CanvasNodeID,
        targetNodeIDs: Set<CanvasNodeID>,
        minimumSpacing: Double = 16
    ) {
        self.axis = axis
        self.fixedNodeID = fixedNodeID
        self.targetNodeIDs = targetNodeIDs
        self.minimumSpacing = minimumSpacing
    }
}
