// Background: Edge routing supports style-specific curves and arrow tangents.
// Responsibility: Host curved edge geometry helpers split from the core routing file.
import Domain
import SwiftUI

extension CanvasEdgeRouting {
    private static let curvedNodeAvoidancePadding: Double = 18
    private static let curvedAvoidanceSampleCount = 32
    private static let curvedAvoidanceMagnitudes: [Double] = [18, 36, 60, 90, 126, 168, 220, 280, 360, 460]

    struct CurveGeometry {
        let control1: CGPoint
        let control2: CGPoint
    }

    private struct CurvedNodeBlocker {
        let bounds: CanvasRect
    }

    static func straightEdgeTipAndVector(
        edge: CanvasEdge,
        routeGeometry: RouteGeometry
    ) -> EdgeTipVector {
        let start = CGPoint(x: routeGeometry.startX, y: routeGeometry.startY)
        let end = CGPoint(x: routeGeometry.endX, y: routeGeometry.endY)
        if edge.directionality == .fromTo {
            return EdgeTipVector(
                tip: end,
                vector: CGVector(dx: end.x - start.x, dy: end.y - start.y)
            )
        }
        if edge.directionality == .toFrom {
            return EdgeTipVector(
                tip: start,
                vector: CGVector(dx: start.x - end.x, dy: start.y - end.y)
            )
        }
        return EdgeTipVector(tip: end, vector: CGVector(dx: 0, dy: 0))
    }

    static func curvedEdgeTipAndVector(
        edge: CanvasEdge,
        routeGeometry: RouteGeometry,
        curve: CurveGeometry
    ) -> EdgeTipVector {
        let start = CGPoint(x: routeGeometry.startX, y: routeGeometry.startY)
        let end = CGPoint(x: routeGeometry.endX, y: routeGeometry.endY)
        if edge.directionality == .fromTo {
            return EdgeTipVector(
                tip: end,
                vector: CGVector(
                    dx: end.x - curve.control2.x,
                    dy: end.y - curve.control2.y
                )
            )
        }
        if edge.directionality == .toFrom {
            return EdgeTipVector(
                tip: start,
                vector: CGVector(
                    dx: start.x - curve.control1.x,
                    dy: start.y - curve.control1.y
                )
            )
        }
        return EdgeTipVector(tip: end, vector: CGVector(dx: 0, dy: 0))
    }

    static func resolvedCurvedGeometry(
        for edge: CanvasEdge,
        routeGeometry: RouteGeometry,
        nodesByID: [CanvasNodeID: CanvasNode],
        laneOffsets: EdgeLaneOffsets,
        nodeAvoidanceEnabled: Bool = true
    ) -> CurveGeometry {
        let baseCurve = curvedGeometry(routeGeometry: routeGeometry, laneOffsets: laneOffsets)
        guard nodeAvoidanceEnabled else {
            return baseCurve
        }
        let blockers = curvedNodeBlockers(for: edge, nodesByID: nodesByID)
        guard !blockers.isEmpty else {
            return baseCurve
        }
        guard firstCurvedBlocker(for: routeGeometry, curve: baseCurve, blockers: blockers) != nil else {
            return baseCurve
        }

        let preferredDirection = preferredAvoidanceDirection(laneOffsets: laneOffsets)
        var candidates: [(curve: CurveGeometry, cost: Double)] = [(baseCurve, .greatestFiniteMagnitude)]

        for magnitude in curvedAvoidanceMagnitudes {
            for direction in [preferredDirection, -preferredDirection] {
                let candidate = curvedGeometry(
                    routeGeometry: routeGeometry,
                    laneOffsets: laneOffsets,
                    avoidanceOffset: magnitude * direction
                )
                guard firstCurvedBlocker(for: routeGeometry, curve: candidate, blockers: blockers) == nil else {
                    continue
                }
                let cost = magnitude + (direction == preferredDirection ? 0 : 0.5)
                candidates.append((candidate, cost))
            }
        }

        return candidates.min { lhs, rhs in
            if lhs.cost != rhs.cost {
                return lhs.cost < rhs.cost
            }
            return isCurveGeometryOrdered(lhs.curve, rhs.curve)
        }?.curve ?? baseCurve
    }

    static func curvedGeometry(
        routeGeometry: RouteGeometry,
        laneOffsets: EdgeLaneOffsets,
        avoidanceOffset: Double = 0
    ) -> CurveGeometry {
        let start = CGPoint(x: routeGeometry.startX, y: routeGeometry.startY)
        let end = CGPoint(x: routeGeometry.endX, y: routeGeometry.endY)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = (dx * dx + dy * dy).squareRoot()
        let safeDistance = max(distance, 1)
        let tangentX = dx / safeDistance
        let tangentY = dy / safeDistance
        let rawNormalX = -tangentY
        let rawNormalY = tangentX
        let handleLength = min(curvedMaxHandleLength, safeDistance * curvedMinHandleRatio)
        let laneAxis = laneAxisVector(for: routeGeometry.axis)
        let laneAlignment = (rawNormalX * laneAxis.dx) + (rawNormalY * laneAxis.dy)
        let normalSign = laneAlignment >= 0 ? 1.0 : -1.0
        let normalX = rawNormalX * normalSign
        let normalY = rawNormalY * normalSign
        let startCurveOffset = curveOffset(for: laneOffsets.start)
        let endCurveOffset = curveOffset(for: laneOffsets.end)
        let startOutwardSign = laneOffsets.start >= 0 ? 1.0 : -1.0
        let endOutwardSign = laneOffsets.end >= 0 ? 1.0 : -1.0

        let control1 = CGPoint(
            x: start.x + (tangentX * handleLength) + (normalX * startCurveOffset * startOutwardSign)
                + (normalX * avoidanceOffset),
            y: start.y + (tangentY * handleLength) + (normalY * startCurveOffset * startOutwardSign)
                + (normalY * avoidanceOffset)
        )
        let control2 = CGPoint(
            x: end.x - (tangentX * handleLength) + (normalX * endCurveOffset * endOutwardSign)
                + (normalX * avoidanceOffset),
            y: end.y - (tangentY * handleLength) + (normalY * endCurveOffset * endOutwardSign)
                + (normalY * avoidanceOffset)
        )
        return CurveGeometry(control1: control1, control2: control2)
    }

    static func cubicBezierPoint(
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

    static func cubicBezierTangent(
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

    private static func curveOffset(for laneOffset: Double) -> Double {
        let laneMagnitude = abs(laneOffset)
        let laneLevel = laneMagnitude / parallelLaneSpacing
        return curvedBaseOffset + (pow(laneLevel, curvedLaneGrowthExponent) * curvedOffsetPerLaneLevel)
    }

    private static func laneAxisVector(for axis: RouteAxis) -> CGVector {
        switch axis {
        case .horizontal:
            return CGVector(dx: 0, dy: 1)
        case .vertical:
            return CGVector(dx: 1, dy: 0)
        }
    }

    private static func curvedNodeBlockers(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> [CurvedNodeBlocker] {
        nodesByID.compactMap { nodeID, node in
            guard nodeID != edge.fromNodeID, nodeID != edge.toNodeID else {
                return nil
            }
            return CurvedNodeBlocker(
                bounds: CanvasRect(
                    minX: node.bounds.x - curvedNodeAvoidancePadding,
                    minY: node.bounds.y - curvedNodeAvoidancePadding,
                    width: node.bounds.width + (curvedNodeAvoidancePadding * 2),
                    height: node.bounds.height + (curvedNodeAvoidancePadding * 2)
                )
            )
        }
        .sorted(by: isCurvedBlockerOrdered)
    }

    private static func preferredAvoidanceDirection(laneOffsets: EdgeLaneOffsets) -> Double {
        let laneBias = laneOffsets.start + laneOffsets.end
        if laneBias > 0 {
            return 1
        }
        if laneBias < 0 {
            return -1
        }
        return 1
    }

    private static func firstCurvedBlocker(
        for routeGeometry: RouteGeometry,
        curve: CurveGeometry,
        blockers: [CurvedNodeBlocker]
    ) -> CurvedNodeBlocker? {
        let start = CGPoint(x: routeGeometry.startX, y: routeGeometry.startY)
        let end = CGPoint(x: routeGeometry.endX, y: routeGeometry.endY)
        let sampledPoints = sampledCurvePoints(start: start, curve: curve, end: end)
        guard sampledPoints.count >= 2 else {
            return nil
        }

        for blocker in blockers {
            for index in 0..<(sampledPoints.count - 1)
            where curvedSegmentIntersectsRect(
                start: sampledPoints[index],
                end: sampledPoints[index + 1],
                rect: blocker.bounds
            ) {
                return blocker
            }
        }

        return nil
    }

    private static func sampledCurvePoints(
        start: CGPoint,
        curve: CurveGeometry,
        end: CGPoint
    ) -> [CGPoint] {
        (0...curvedAvoidanceSampleCount).map { index in
            let parameter = CGFloat(index) / CGFloat(curvedAvoidanceSampleCount)
            return cubicBezierPoint(
                start: start,
                control1: curve.control1,
                control2: curve.control2,
                end: end,
                parameter: parameter
            )
        }
    }

    private static func curvedSegmentIntersectsRect(
        start: CGPoint,
        end: CGPoint,
        rect: CanvasRect
    ) -> Bool {
        let minX = min(Double(start.x), Double(end.x))
        let maxX = max(Double(start.x), Double(end.x))
        let minY = min(Double(start.y), Double(end.y))
        let maxY = max(Double(start.y), Double(end.y))
        guard maxX >= rect.minX, minX <= rect.maxX, maxY >= rect.minY, minY <= rect.maxY else {
            return false
        }

        if rectContains(point: start, rect: rect) || rectContains(point: end, rect: rect) {
            return true
        }

        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        return
            segmentsIntersect(start, end, topLeft, topRight)
            || segmentsIntersect(start, end, topRight, bottomRight)
            || segmentsIntersect(start, end, bottomRight, bottomLeft)
            || segmentsIntersect(start, end, bottomLeft, topLeft)
    }

    private static func rectContains(point: CGPoint, rect: CanvasRect) -> Bool {
        Double(point.x) >= rect.minX
            && Double(point.x) <= rect.maxX
            && Double(point.y) >= rect.minY
            && Double(point.y) <= rect.maxY
    }

    private static func segmentsIntersect(
        _ pointA: CGPoint,
        _ pointB: CGPoint,
        _ pointC: CGPoint,
        _ pointD: CGPoint
    ) -> Bool {
        let abx = Double(pointB.x - pointA.x)
        let aby = Double(pointB.y - pointA.y)
        let acx = Double(pointC.x - pointA.x)
        let acy = Double(pointC.y - pointA.y)
        let adx = Double(pointD.x - pointA.x)
        let ady = Double(pointD.y - pointA.y)
        let cdx = Double(pointD.x - pointC.x)
        let cdy = Double(pointD.y - pointC.y)
        let cax = Double(pointA.x - pointC.x)
        let cay = Double(pointA.y - pointC.y)
        let cbx = Double(pointB.x - pointC.x)
        let cby = Double(pointB.y - pointC.y)

        let cross1 = cross(dx: abx, dy: aby, otherDX: acx, otherDY: acy)
        let cross2 = cross(dx: abx, dy: aby, otherDX: adx, otherDY: ady)
        let cross3 = cross(dx: cdx, dy: cdy, otherDX: cax, otherDY: cay)
        let cross4 = cross(dx: cdx, dy: cdy, otherDX: cbx, otherDY: cby)

        if cross1 == 0, onSegment(point: pointC, segmentStart: pointA, segmentEnd: pointB) {
            return true
        }
        if cross2 == 0, onSegment(point: pointD, segmentStart: pointA, segmentEnd: pointB) {
            return true
        }
        if cross3 == 0, onSegment(point: pointA, segmentStart: pointC, segmentEnd: pointD) {
            return true
        }
        if cross4 == 0, onSegment(point: pointB, segmentStart: pointC, segmentEnd: pointD) {
            return true
        }

        return ((cross1 > 0) != (cross2 > 0)) && ((cross3 > 0) != (cross4 > 0))
    }

    private static func cross(dx: Double, dy: Double, otherDX: Double, otherDY: Double) -> Double {
        (dx * otherDY) - (dy * otherDX)
    }

    private static func onSegment(
        point: CGPoint,
        segmentStart: CGPoint,
        segmentEnd: CGPoint
    ) -> Bool {
        let epsilon = 0.0001
        return Double(point.x) >= min(Double(segmentStart.x), Double(segmentEnd.x)) - epsilon
            && Double(point.x) <= max(Double(segmentStart.x), Double(segmentEnd.x)) + epsilon
            && Double(point.y) >= min(Double(segmentStart.y), Double(segmentEnd.y)) - epsilon
            && Double(point.y) <= max(Double(segmentStart.y), Double(segmentEnd.y)) + epsilon
    }

    private static func isCurvedBlockerOrdered(_ lhs: CurvedNodeBlocker, _ rhs: CurvedNodeBlocker) -> Bool {
        if lhs.bounds.minX != rhs.bounds.minX {
            return lhs.bounds.minX < rhs.bounds.minX
        }
        if lhs.bounds.minY != rhs.bounds.minY {
            return lhs.bounds.minY < rhs.bounds.minY
        }
        if lhs.bounds.maxX != rhs.bounds.maxX {
            return lhs.bounds.maxX < rhs.bounds.maxX
        }
        return lhs.bounds.maxY < rhs.bounds.maxY
    }

    private static func isCurveGeometryOrdered(_ lhs: CurveGeometry, _ rhs: CurveGeometry) -> Bool {
        if lhs.control1.x != rhs.control1.x {
            return lhs.control1.x < rhs.control1.x
        }
        if lhs.control1.y != rhs.control1.y {
            return lhs.control1.y < rhs.control1.y
        }
        if lhs.control2.x != rhs.control2.x {
            return lhs.control2.x < rhs.control2.x
        }
        return lhs.control2.y < rhs.control2.y
    }
}
