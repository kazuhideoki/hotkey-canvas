// Background: Legacy avoidance explores multiple equivalent orthogonal routes
// for the same rendered edge.
// Responsibility: Keep blocker ordering and route selection deterministic
// across legacy path, arrow, and label consumers.
import Domain
import SwiftUI

extension CanvasEdgeRouting {
    static func isLegacyBlockerBefore(_ lhs: LegacyNodeBlocker, _ rhs: LegacyNodeBlocker) -> Bool {
        let lhsMinX = quantizedValue(lhs.bounds.minX)
        let rhsMinX = quantizedValue(rhs.bounds.minX)
        if lhsMinX != rhsMinX {
            return lhsMinX < rhsMinX
        }

        let lhsMinY = quantizedValue(lhs.bounds.minY)
        let rhsMinY = quantizedValue(rhs.bounds.minY)
        if lhsMinY != rhsMinY {
            return lhsMinY < rhsMinY
        }

        let lhsMaxX = quantizedValue(lhs.bounds.maxX)
        let rhsMaxX = quantizedValue(rhs.bounds.maxX)
        if lhsMaxX != rhsMaxX {
            return lhsMaxX < rhsMaxX
        }

        return quantizedValue(lhs.bounds.maxY) < quantizedValue(rhs.bounds.maxY)
    }

    static func routeSignature(route: PolylineRoute) -> String {
        route.points
            .map { point in
                "\(quantizedValue(Double(point.x))):\(quantizedValue(Double(point.y)))"
            }
            .joined(separator: "|")
    }

    static func isRouteSignatureBefore(_ lhs: PolylineRoute, _ rhs: PolylineRoute) -> Bool {
        routeSignature(route: lhs) < routeSignature(route: rhs)
    }

    static func quantizedValue(_ value: Double) -> Int {
        Int((value * 1_000).rounded())
    }
}
