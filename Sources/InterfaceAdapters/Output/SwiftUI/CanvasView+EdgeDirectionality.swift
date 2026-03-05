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
        guard
            let geometry = CanvasEdgeRouting.routeGeometry(
                for: edge,
                nodesByID: context.nodesByID,
                branchCoordinateByParentAndDirection: context.branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: context.laneOffsetsByEdgeID
            )
        else {
            return nil
        }

        let tipAndVector = arrowTipAndVector(for: edge.directionality, geometry: geometry)
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

    private func arrowTipAndVector(
        for directionality: CanvasEdgeDirectionality,
        geometry: CanvasEdgeRouting.RouteGeometry
    ) -> (tip: CGPoint, vector: CGVector) {
        switch directionality {
        case .fromTo:
            let tip = CGPoint(x: geometry.endX, y: geometry.endY)
            let near = nearPointTowardEnd(for: geometry)
            return (
                tip,
                CGVector(dx: tip.x - near.x, dy: tip.y - near.y)
            )
        case .toFrom:
            let tip = CGPoint(x: geometry.startX, y: geometry.startY)
            let near = nearPointTowardStart(for: geometry)
            return (
                tip,
                CGVector(dx: tip.x - near.x, dy: tip.y - near.y)
            )
        default:
            return (CGPoint(x: geometry.endX, y: geometry.endY), CGVector(dx: 0, dy: 0))
        }
    }

    private func nearPointTowardEnd(for geometry: CanvasEdgeRouting.RouteGeometry) -> CGPoint {
        switch geometry.axis {
        case .horizontal:
            return CGPoint(x: geometry.branchCoordinate, y: geometry.endY)
        case .vertical:
            return CGPoint(x: geometry.endX, y: geometry.branchCoordinate)
        }
    }

    private func nearPointTowardStart(for geometry: CanvasEdgeRouting.RouteGeometry) -> CGPoint {
        switch geometry.axis {
        case .horizontal:
            return CGPoint(x: geometry.branchCoordinate, y: geometry.startY)
        case .vertical:
            return CGPoint(x: geometry.startX, y: geometry.branchCoordinate)
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
