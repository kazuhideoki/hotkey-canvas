// Background: Edge paths are already routed.
// Directionality needs a visual arrow without changing route computation.
// Responsibility: Render arrowheads for directed edges based on route geometry.
import Domain
import SwiftUI

extension CanvasView {
    struct EdgeRenderContext {
        let nodesByID: [CanvasNodeID: CanvasNode]
        let branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double]
        let treeBranchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double]
        let laneOffsetsByEdgeID: [CanvasEdgeID: CanvasEdgeRouting.EdgeLaneOffsets]
        let areaIDByNodeID: [CanvasNodeID: CanvasAreaID]
        let areaEditingModeByID: [CanvasAreaID: CanvasEditingMode]
        let areaEdgeShapeStyleByID: [CanvasAreaID: CanvasAreaEdgeShapeStyle]
    }

    func edgeStrokeAndArrow(
        edge: CanvasEdge,
        strokeColor: Color,
        strokeWidth: CGFloat,
        context: EdgeRenderContext
    ) -> some View {
        let areaID = context.areaIDByNodeID[edge.fromNodeID]
        let edgeShapeStyle = areaID.flatMap { context.areaEdgeShapeStyleByID[$0] } ?? .curved
        let editingMode = areaID.flatMap { context.areaEditingModeByID[$0] }
        let routingStyle: CanvasEdgeRouting.RoutingStyle = editingMode == .tree ? .treeSimple : .adaptive
        let nodeAvoidanceEnabled = editingMode != .tree
        let branchCoordinateByParentAndDirection =
            routingStyle == .treeSimple
            ? context.treeBranchCoordinateByParentAndDirection
            : context.branchCoordinateByParentAndDirection
        return Group {
            if let path = CanvasEdgeRouting.path(
                for: edge,
                nodesByID: context.nodesByID,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: context.laneOffsetsByEdgeID,
                edgeShapeStyle: edgeShapeStyle,
                routingStyle: routingStyle,
                nodeAvoidanceEnabled: nodeAvoidanceEnabled
            ) {
                path.stroke(strokeColor, lineWidth: strokeWidth)
                if let arrowPath = edgeArrowPath(
                    edge: edge,
                    strokeWidth: strokeWidth,
                    context: context
                ) {
                    arrowPath.fill(strokeColor)
                }
            }
        }
    }
}

extension CanvasView {
    private static let edgeArrowLengthFactor: CGFloat = 2.8
    private static let edgeArrowHalfWidthFactor: CGFloat = 1.8

    static func edgeArrowMetrics(strokeWidth: CGFloat) -> (length: CGFloat, halfWidth: CGFloat) {
        (
            length: max(8, strokeWidth * Self.edgeArrowLengthFactor),
            halfWidth: max(4, strokeWidth * Self.edgeArrowHalfWidthFactor)
        )
    }

    private func edgeArrowPath(
        edge: CanvasEdge,
        strokeWidth: CGFloat,
        context: EdgeRenderContext
    ) -> Path? {
        guard edge.directionality != .none else {
            return nil
        }
        let areaID = context.areaIDByNodeID[edge.fromNodeID]
        let edgeShapeStyle = areaID.flatMap { context.areaEdgeShapeStyleByID[$0] } ?? .curved
        let editingMode = areaID.flatMap { context.areaEditingModeByID[$0] }
        let routingStyle: CanvasEdgeRouting.RoutingStyle = editingMode == .tree ? .treeSimple : .adaptive
        let nodeAvoidanceEnabled = editingMode != .tree
        let branchCoordinateByParentAndDirection =
            routingStyle == .treeSimple
            ? context.treeBranchCoordinateByParentAndDirection
            : context.branchCoordinateByParentAndDirection
        guard
            let tipAndVector = CanvasEdgeRouting.edgeTipAndVector(
                for: edge,
                nodesByID: context.nodesByID,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: context.laneOffsetsByEdgeID,
                edgeShapeStyle: edgeShapeStyle,
                routingStyle: routingStyle,
                nodeAvoidanceEnabled: nodeAvoidanceEnabled
            ),
            let unitVector = normalize(vector: tipAndVector.vector)
        else {
            return nil
        }

        let arrowMetrics = Self.edgeArrowMetrics(strokeWidth: strokeWidth)
        let baseCenter = CGPoint(
            x: tipAndVector.tip.x - (unitVector.dx * arrowMetrics.length),
            y: tipAndVector.tip.y - (unitVector.dy * arrowMetrics.length)
        )
        let perpendicular = CGVector(dx: -unitVector.dy, dy: unitVector.dx)
        let left = CGPoint(
            x: baseCenter.x + (perpendicular.dx * arrowMetrics.halfWidth),
            y: baseCenter.y + (perpendicular.dy * arrowMetrics.halfWidth)
        )
        let right = CGPoint(
            x: baseCenter.x - (perpendicular.dx * arrowMetrics.halfWidth),
            y: baseCenter.y - (perpendicular.dy * arrowMetrics.halfWidth)
        )

        return Path { path in
            path.move(to: tipAndVector.tip)
            path.addLine(to: left)
            path.addLine(to: right)
            path.closeSubpath()
        }
    }

    private func normalize(vector: CGVector) -> CGVector? {
        let length = sqrt((vector.dx * vector.dx) + (vector.dy * vector.dy))
        guard length > 0.001 else {
            return nil
        }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
}
