// Background: Legacy edge helpers need one shared route description before node avoidance is added.
// Responsibility: Represent legacy edge geometry as a canonical polyline for path, arrow, and label consumers.
import Domain
import SwiftUI

extension CanvasEdgeRouting {
    /// Canonical polyline route shared by legacy edge rendering helpers.
    struct PolylineRoute: Equatable {
        let start: CGPoint
        let bendPoints: [CGPoint]
        let end: CGPoint

        var points: [CGPoint] {
            [start] + bendPoints + [end]
        }

        var pointAfterStart: CGPoint {
            bendPoints.first ?? end
        }

        var pointBeforeEnd: CGPoint {
            bendPoints.last ?? start
        }
    }

    /// Returns the canonical legacy polyline for the supplied elbow geometry.
    static func legacyPolylineRoute(routeGeometry: RouteGeometry) -> PolylineRoute {
        let start = CGPoint(x: routeGeometry.startX, y: routeGeometry.startY)
        let end = CGPoint(x: routeGeometry.endX, y: routeGeometry.endY)

        switch routeGeometry.axis {
        case .horizontal:
            return PolylineRoute(
                start: start,
                bendPoints: [
                    CGPoint(x: routeGeometry.branchCoordinate, y: routeGeometry.startY),
                    CGPoint(x: routeGeometry.branchCoordinate, y: routeGeometry.endY),
                ],
                end: end
            )
        case .vertical:
            return PolylineRoute(
                start: start,
                bendPoints: [
                    CGPoint(x: routeGeometry.startX, y: routeGeometry.branchCoordinate),
                    CGPoint(x: routeGeometry.endX, y: routeGeometry.branchCoordinate),
                ],
                end: end
            )
        }
    }

    /// Adds all segments of a polyline route to an existing path.
    static func addPolylinePathSegments(path: inout Path, route: PolylineRoute) {
        for bendPoint in route.bendPoints {
            path.addLine(to: bendPoint)
        }
        path.addLine(to: route.end)
    }

    /// Returns the arrow tip and vector derived from the legacy polyline.
    static func legacyEdgeTipAndVector(
        edge: CanvasEdge,
        polylineRoute: PolylineRoute
    ) -> EdgeTipVector {
        if edge.directionality == .fromTo {
            let tip = polylineRoute.end
            let previousPoint = polylineRoute.pointBeforeEnd
            return EdgeTipVector(
                tip: tip,
                vector: CGVector(dx: tip.x - previousPoint.x, dy: tip.y - previousPoint.y)
            )
        }
        if edge.directionality == .toFrom {
            let tip = polylineRoute.start
            let nextPoint = polylineRoute.pointAfterStart
            return EdgeTipVector(
                tip: tip,
                vector: CGVector(dx: tip.x - nextPoint.x, dy: tip.y - nextPoint.y)
            )
        }
        return EdgeTipVector(tip: polylineRoute.end, vector: CGVector(dx: 0, dy: 0))
    }
}
