// Background: Edge routing supports style-specific curves and arrow tangents.
// Responsibility: Host curved edge geometry helpers split from the core routing file.
import Domain
import SwiftUI

extension CanvasEdgeRouting {
    struct CurveGeometry {
        let control1: CGPoint
        let control2: CGPoint
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

    static func curvedGeometry(
        routeGeometry: RouteGeometry,
        laneOffsets: EdgeLaneOffsets
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
            x: start.x + (tangentX * handleLength) + (normalX * startCurveOffset * startOutwardSign),
            y: start.y + (tangentY * handleLength) + (normalY * startCurveOffset * startOutwardSign)
        )
        let control2 = CGPoint(
            x: end.x - (tangentX * handleLength) + (normalX * endCurveOffset * endOutwardSign),
            y: end.y - (tangentY * handleLength) + (normalY * endCurveOffset * endOutwardSign)
        )
        return CurveGeometry(control1: control1, control2: control2)
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
}
