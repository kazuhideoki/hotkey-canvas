// Background: Diagram alignment commands need declarative post-processing after mutation.
// Responsibility: Describe overlap-resolution constraints for aligned diagram nodes.
import Domain

/// Constraint used by the pipeline to preserve a diagram alignment axis during overlap resolution.
public struct CanvasDiagramAlignmentConstraint: Equatable, Sendable {
    public let axis: CanvasNodeAlignmentAxis
    public let fixedNodeID: CanvasNodeID
    public let targetNodeIDs: Set<CanvasNodeID>
    public let minimumSpacing: Double

    public init(
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
