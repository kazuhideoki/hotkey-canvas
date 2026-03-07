// Background: Edge labels should follow the actual rendered route instead of a simplified route midpoint.
// Responsibility: Compute shape-aware label anchors and normals for each routed edge style.
import Domain
import SwiftUI

extension CanvasEdgeRouting {
    /// Anchor point and outward normal used for edge label placement.
    struct EdgeLabelAnchor: Equatable {
        let point: CGPoint
        let tangent: CGVector
        let normal: CGVector
    }

    static func labelAnchor(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode],
        branchCoordinateByParentAndDirection: [BranchKey: Double],
        laneOffsetsByEdgeID: [CanvasEdgeID: EdgeLaneOffsets] = [:],
        edgeShapeStyle: CanvasAreaEdgeShapeStyle
    ) -> EdgeLabelAnchor? {
        guard
            let geometry = routeGeometry(
                for: edge,
                nodesByID: nodesByID,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: laneOffsetsByEdgeID
            )
        else {
            return nil
        }

        switch edgeShapeStyle {
        case .straight:
            let start = CGPoint(x: geometry.startX, y: geometry.startY)
            let end = CGPoint(x: geometry.endX, y: geometry.endY)
            let tangent = CGVector(dx: end.x - start.x, dy: end.y - start.y)
            return EdgeLabelAnchor(
                point: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2),
                tangent: normalized(vector: tangent) ?? CGVector(dx: 1, dy: 0),
                normal: perpendicularUnitVector(for: tangent)
            )
        case .legacy:
            return legacyLabelAnchor(routeGeometry: geometry)
        case .curved:
            let laneOffsets = laneOffsetsByEdgeID[edge.id] ?? .zero
            let curve = curvedGeometry(routeGeometry: geometry, laneOffsets: laneOffsets)
            return curvedLabelAnchor(routeGeometry: geometry, curve: curve)
        }
    }
}

extension CanvasEdgeRouting {
    private struct SampledCurve {
        let parameters: [CGFloat]
        let cumulativeLengths: [CGFloat]
        let totalLength: CGFloat
    }

    private static func legacyLabelAnchor(routeGeometry: RouteGeometry) -> EdgeLabelAnchor {
        polylineLabelAnchor(points: legacyPoints(routeGeometry: routeGeometry))
    }

    private static func curvedLabelAnchor(
        routeGeometry: RouteGeometry,
        curve: CurveGeometry
    ) -> EdgeLabelAnchor {
        let start = CGPoint(x: routeGeometry.startX, y: routeGeometry.startY)
        let end = CGPoint(x: routeGeometry.endX, y: routeGeometry.endY)
        let sampledCurve = sampleCubicBezierCurve(start: start, curve: curve, end: end, sampleCount: 32)

        guard sampledCurve.totalLength > 0 else {
            return anchor(point: start, tangent: CGVector(dx: end.x - start.x, dy: end.y - start.y))
        }

        if let midpointAnchor = sampledCurveMidpointAnchor(
            sampledCurve: sampledCurve,
            start: start,
            curve: curve,
            end: end
        ) {
            return midpointAnchor
        }

        return sampledCurveFallbackAnchor(start: start, curve: curve, end: end)
    }

    private static func sampledCurveMidpointAnchor(
        sampledCurve: SampledCurve,
        start: CGPoint,
        curve: CurveGeometry,
        end: CGPoint
    ) -> EdgeLabelAnchor? {
        let targetLength = sampledCurve.totalLength / 2
        for index in 1..<sampledCurve.cumulativeLengths.count {
            let previousLength = sampledCurve.cumulativeLengths[index - 1]
            let currentLength = sampledCurve.cumulativeLengths[index]
            guard targetLength <= currentLength else {
                continue
            }
            let segmentLength = max(currentLength - previousLength, 0.0001)
            let localRatio = (targetLength - previousLength) / segmentLength
            let previousParameter = sampledCurve.parameters[index - 1]
            let currentParameter = sampledCurve.parameters[index]
            let parameter = previousParameter + ((currentParameter - previousParameter) * localRatio)
            let point = cubicBezierPoint(
                start: start,
                control1: curve.control1,
                control2: curve.control2,
                end: end,
                parameter: parameter
            )
            let tangent = cubicBezierTangent(
                start: start,
                control1: curve.control1,
                control2: curve.control2,
                end: end,
                parameter: parameter
            )
            return anchor(point: point, tangent: tangent)
        }
        return nil
    }

    private static func sampledCurveFallbackAnchor(
        start: CGPoint,
        curve: CurveGeometry,
        end: CGPoint
    ) -> EdgeLabelAnchor {
        let fallbackParameter: CGFloat = 0.5
        let tangent = cubicBezierTangent(
            start: start,
            control1: curve.control1,
            control2: curve.control2,
            end: end,
            parameter: fallbackParameter
        )
        let point = cubicBezierPoint(
            start: start,
            control1: curve.control1,
            control2: curve.control2,
            end: end,
            parameter: fallbackParameter
        )
        return anchor(point: point, tangent: tangent)
    }

    private static func anchor(point: CGPoint, tangent: CGVector) -> EdgeLabelAnchor {
        return EdgeLabelAnchor(
            point: point,
            tangent: normalized(vector: tangent) ?? CGVector(dx: 1, dy: 0),
            normal: perpendicularUnitVector(for: tangent)
        )
    }

    private static func sampleCubicBezierCurve(
        start: CGPoint,
        curve: CurveGeometry,
        end: CGPoint,
        sampleCount: Int
    ) -> SampledCurve {
        var previousPoint = start
        var cumulativeLengths: [CGFloat] = [0]
        var sampledParameters: [CGFloat] = [0]
        var totalLength: CGFloat = 0

        for index in 1...sampleCount {
            let parameter = CGFloat(index) / CGFloat(sampleCount)
            let point = cubicBezierPoint(
                start: start,
                control1: curve.control1,
                control2: curve.control2,
                end: end,
                parameter: parameter
            )
            totalLength += distance(from: previousPoint, to: point)
            cumulativeLengths.append(totalLength)
            sampledParameters.append(parameter)
            previousPoint = point
        }

        return SampledCurve(
            parameters: sampledParameters,
            cumulativeLengths: cumulativeLengths,
            totalLength: totalLength
        )
    }

    private static func legacyPoints(routeGeometry: RouteGeometry) -> [CGPoint] {
        let start = CGPoint(x: routeGeometry.startX, y: routeGeometry.startY)
        let end = CGPoint(x: routeGeometry.endX, y: routeGeometry.endY)
        switch routeGeometry.axis {
        case .horizontal:
            return [
                start,
                CGPoint(x: routeGeometry.branchCoordinate, y: routeGeometry.startY),
                CGPoint(x: routeGeometry.branchCoordinate, y: routeGeometry.endY),
                end,
            ]
        case .vertical:
            return [
                start,
                CGPoint(x: routeGeometry.startX, y: routeGeometry.branchCoordinate),
                CGPoint(x: routeGeometry.endX, y: routeGeometry.branchCoordinate),
                end,
            ]
        }
    }

    private static func polylineLabelAnchor(points: [CGPoint]) -> EdgeLabelAnchor {
        guard points.count >= 2 else {
            return EdgeLabelAnchor(
                point: points.first ?? .zero,
                tangent: CGVector(dx: 1, dy: 0),
                normal: CGVector(dx: 0, dy: -1)
            )
        }

        var segmentLengths: [CGFloat] = []
        var totalLength: CGFloat = 0
        for index in 1..<points.count {
            let length = distance(from: points[index - 1], to: points[index])
            segmentLengths.append(length)
            totalLength += length
        }

        guard totalLength > 0 else {
            let tangent = CGVector(dx: points[1].x - points[0].x, dy: points[1].y - points[0].y)
            return EdgeLabelAnchor(
                point: points[0],
                tangent: normalized(vector: tangent) ?? CGVector(dx: 1, dy: 0),
                normal: perpendicularUnitVector(for: tangent)
            )
        }

        let targetLength = totalLength / 2
        var traversed: CGFloat = 0
        for index in 1..<points.count {
            let segmentLength = segmentLengths[index - 1]
            let nextTraversed = traversed + segmentLength
            guard targetLength <= nextTraversed else {
                traversed = nextTraversed
                continue
            }
            let start = points[index - 1]
            let end = points[index]
            let segmentRatio = segmentLength > 0 ? (targetLength - traversed) / segmentLength : 0
            let point = CGPoint(
                x: start.x + ((end.x - start.x) * segmentRatio),
                y: start.y + ((end.y - start.y) * segmentRatio)
            )
            let tangent = CGVector(dx: end.x - start.x, dy: end.y - start.y)
            return EdgeLabelAnchor(
                point: point,
                tangent: normalized(vector: tangent) ?? CGVector(dx: 1, dy: 0),
                normal: perpendicularUnitVector(for: tangent)
            )
        }

        let finalStart = points[points.count - 2]
        let finalEnd = points[points.count - 1]
        let tangent = CGVector(dx: finalEnd.x - finalStart.x, dy: finalEnd.y - finalStart.y)
        return EdgeLabelAnchor(
            point: finalEnd,
            tangent: normalized(vector: tangent) ?? CGVector(dx: 1, dy: 0),
            normal: perpendicularUnitVector(for: tangent)
        )
    }

    private static func perpendicularUnitVector(for tangent: CGVector) -> CGVector {
        let length = sqrt((tangent.dx * tangent.dx) + (tangent.dy * tangent.dy))
        guard length > 0.0001 else {
            return CGVector(dx: 0, dy: -1)
        }
        return CGVector(dx: -tangent.dy / length, dy: tangent.dx / length)
    }

    private static func normalized(vector: CGVector) -> CGVector? {
        let length = sqrt((vector.dx * vector.dx) + (vector.dy * vector.dy))
        guard length > 0.0001 else {
            return nil
        }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    private static func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = rhs.x - lhs.x
        let dy = rhs.y - lhs.y
        return sqrt((dx * dx) + (dy * dy))
    }

    private static func cubicBezierPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        parameter: CGFloat
    ) -> CGPoint {
        let oneMinusParameter = 1 - parameter
        let cubicStartWeight = oneMinusParameter * oneMinusParameter * oneMinusParameter
        let cubicControl1Weight = 3 * oneMinusParameter * oneMinusParameter * parameter
        let cubicControl2Weight = 3 * oneMinusParameter * parameter * parameter
        let cubicEndWeight = parameter * parameter * parameter
        return CGPoint(
            x: (start.x * cubicStartWeight) + (control1.x * cubicControl1Weight)
                + (control2.x * cubicControl2Weight) + (end.x * cubicEndWeight),
            y: (start.y * cubicStartWeight) + (control1.y * cubicControl1Weight)
                + (control2.y * cubicControl2Weight) + (end.y * cubicEndWeight)
        )
    }

    private static func cubicBezierTangent(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        parameter: CGFloat
    ) -> CGVector {
        let oneMinusParameter = 1 - parameter
        let dx =
            3 * oneMinusParameter * oneMinusParameter * (control1.x - start.x)
            + 6 * oneMinusParameter * parameter * (control2.x - control1.x)
            + 3 * parameter * parameter * (end.x - control2.x)
        let dy =
            3 * oneMinusParameter * oneMinusParameter * (control1.y - start.y)
            + 6 * oneMinusParameter * parameter * (control2.y - control1.y)
            + 3 * parameter * parameter * (end.y - control2.y)
        return CGVector(dx: dx, dy: dy)
    }
}
