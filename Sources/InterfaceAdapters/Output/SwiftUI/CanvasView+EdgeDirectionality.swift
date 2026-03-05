// Background: Edge paths are already routed.
// Directionality needs a visual arrow without changing route computation.
// Responsibility: Render arrowheads for directed edges based on route geometry.
import Domain
import SwiftUI

extension CanvasView {
    struct EdgeRenderContext {
        let nodesByID: [CanvasNodeID: CanvasNode]
        let branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double]
        let laneOffsetsByEdgeID: [CanvasEdgeID: CanvasEdgeRouting.EdgeLaneOffsets]
        let areaIDByNodeID: [CanvasNodeID: CanvasAreaID]
        let areaEdgeShapeStyleByID: [CanvasAreaID: CanvasAreaEdgeShapeStyle]
        let viewportSize: CGSize
        let zoomScale: Double
        let cameraOffset: CGSize
    }

    @ViewBuilder
    func edgeStrokeAndArrow(
        edge: CanvasEdge,
        path: Path,
        strokeColor: Color,
        strokeWidth: CGFloat,
        context: EdgeRenderContext
    ) -> some View {
        let zoomAdjustedStrokeWidth = strokeWidth * CGFloat(context.zoomScale)
        let transform = CanvasViewportTransform.affineTransform(
            viewportSize: context.viewportSize,
            zoomScale: context.zoomScale,
            effectiveOffset: context.cameraOffset
        )
        path
            .applying(transform)
            .stroke(strokeColor, lineWidth: zoomAdjustedStrokeWidth)

        if let arrowPath = edgeArrowPath(
            edge: edge,
            strokeWidth: strokeWidth,
            context: context
        ) {
            arrowPath
                .applying(transform)
                .fill(strokeColor)
        }
    }
}

extension CanvasView {
    private static let edgeArrowLengthFactor: CGFloat = 2.8
    private static let edgeArrowHalfWidthFactor: CGFloat = 1.8
    static func edgeArrowZoomCompensation(for zoomScale: Double) -> CGFloat {
        if zoomScale < 1.0 {
            return CGFloat(1.0 / zoomScale)
        }
        return 1.0
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
        guard
            let tipAndVector = CanvasEdgeRouting.edgeTipAndVector(
                for: edge,
                nodesByID: context.nodesByID,
                branchCoordinateByParentAndDirection: context.branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: context.laneOffsetsByEdgeID,
                edgeShapeStyle: edgeShapeStyle
            )
        else {
            return nil
        }

        guard let unitVector = normalize(vector: tipAndVector.vector) else {
            return nil
        }

        let zoomCompensation = Self.edgeArrowZoomCompensation(for: context.zoomScale)
        let arrowLength =
            max(8, strokeWidth * Self.edgeArrowLengthFactor)
            * zoomCompensation
        let arrowHalfWidth =
            max(4, strokeWidth * Self.edgeArrowHalfWidthFactor)
            * zoomCompensation
        let baseCenter = CGPoint(
            x: tipAndVector.tip.x - (unitVector.dx * arrowLength),
            y: tipAndVector.tip.y - (unitVector.dy * arrowLength)
        )
        let perpendicular = CGVector(dx: -unitVector.dy, dy: unitVector.dx)
        let left = CGPoint(
            x: baseCenter.x + (perpendicular.dx * arrowHalfWidth),
            y: baseCenter.y + (perpendicular.dy * arrowHalfWidth)
        )
        let right = CGPoint(
            x: baseCenter.x - (perpendicular.dx * arrowHalfWidth),
            y: baseCenter.y - (perpendicular.dy * arrowHalfWidth)
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
