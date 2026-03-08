// Background: Legacy edges now use a canonical polyline, enabling local node-avoidance without changing other styles.
// Responsibility: Resolve legacy-only blocker detours while preserving stable endpoint anchors and route ordering.
import Domain
import SwiftUI

extension CanvasEdgeRouting {
    private static let legacyNodeAvoidancePadding: Double = 18
    private static let legacyMaximumDetourDepth = 4
    private static let legacyMaximumExploredRoutes = 48
    private static let legacyBendPenalty: Double = 60
    private static let legacyEpsilon: Double = 0.0001

    struct LegacyNodeBlocker {
        let bounds: CanvasRect
    }

    private struct LegacyBlockerHit {
        let segmentIndex: Int
        let blocker: LegacyNodeBlocker
    }

    private struct LegacyRouteCandidate {
        let route: PolylineRoute
        let depth: Int
        let cost: Double
    }

    /// Returns the legacy route after detouring around non-endpoint nodes when needed.
    static func legacyPolylineRoute(
        for edge: CanvasEdge,
        routeGeometry: RouteGeometry,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> PolylineRoute {
        let baseRoute = legacyPolylineRoute(routeGeometry: routeGeometry)
        let blockers = legacyNodeBlockers(for: edge, nodesByID: nodesByID)
        guard !blockers.isEmpty else {
            return baseRoute
        }
        return resolvedLegacyPolylineRoute(baseRoute: baseRoute, blockers: blockers)
    }
}

extension CanvasEdgeRouting {
    private static func legacyNodeBlockers(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> [LegacyNodeBlocker] {
        nodesByID.compactMap { nodeID, node in
            guard nodeID != edge.fromNodeID, nodeID != edge.toNodeID else {
                return nil
            }
            return LegacyNodeBlocker(
                bounds: CanvasRect(
                    minX: node.bounds.x - legacyNodeAvoidancePadding,
                    minY: node.bounds.y - legacyNodeAvoidancePadding,
                    width: node.bounds.width + (legacyNodeAvoidancePadding * 2),
                    height: node.bounds.height + (legacyNodeAvoidancePadding * 2)
                )
            )
        }
        .sorted(by: isLegacyBlockerBefore)
    }

    private static func resolvedLegacyPolylineRoute(
        baseRoute: PolylineRoute,
        blockers: [LegacyNodeBlocker]
    ) -> PolylineRoute {
        var frontier: [LegacyRouteCandidate] = [
            LegacyRouteCandidate(
                route: baseRoute,
                depth: 0,
                cost: legacyRouteCost(route: baseRoute, baseRoute: baseRoute)
            )
        ]
        var visited: Set<String> = []
        var exploredRouteCount = 0

        while !frontier.isEmpty, exploredRouteCount < legacyMaximumExploredRoutes {
            frontier.sort(by: isLegacyRouteCandidateBetter)
            let candidate = frontier.removeFirst()
            let signature = routeSignature(route: candidate.route)
            guard visited.insert(signature).inserted else {
                continue
            }
            exploredRouteCount += 1

            guard !legacyRouteHasSelfIntersection(candidate.route) else {
                continue
            }
            guard let hit = firstLegacyBlockerHit(for: candidate.route, blockers: blockers) else {
                return candidate.route
            }
            guard candidate.depth < legacyMaximumDetourDepth else {
                continue
            }

            for nextRoute in legacyDetourRoutes(for: candidate.route, hit: hit) {
                let nextSignature = routeSignature(route: nextRoute)
                guard !visited.contains(nextSignature) else {
                    continue
                }
                frontier.append(
                    LegacyRouteCandidate(
                        route: nextRoute,
                        depth: candidate.depth + 1,
                        cost: legacyRouteCost(route: nextRoute, baseRoute: baseRoute)
                    )
                )
            }
        }

        return baseRoute
    }

    private static func isLegacyRouteCandidateBetter(_ lhs: LegacyRouteCandidate, _ rhs: LegacyRouteCandidate) -> Bool {
        if lhs.cost != rhs.cost {
            return lhs.cost < rhs.cost
        }
        if lhs.depth != rhs.depth {
            return lhs.depth < rhs.depth
        }
        if lhs.route.bendPoints.count != rhs.route.bendPoints.count {
            return lhs.route.bendPoints.count < rhs.route.bendPoints.count
        }
        let lhsLength = legacyRouteLength(lhs.route)
        let rhsLength = legacyRouteLength(rhs.route)
        if lhsLength != rhsLength {
            return lhsLength < rhsLength
        }
        return routeSignature(route: lhs.route) < routeSignature(route: rhs.route)
    }

    private static func firstLegacyBlockerHit(
        for route: PolylineRoute,
        blockers: [LegacyNodeBlocker]
    ) -> LegacyBlockerHit? {
        let points = route.points
        guard points.count >= 2 else {
            return nil
        }

        for segmentIndex in 0..<(points.count - 1) {
            let start = points[segmentIndex]
            let end = points[segmentIndex + 1]
            let segmentHits = blockers.filter { blocker in
                segmentIntersectsRect(start: start, end: end, rect: blocker.bounds)
            }
            guard !segmentHits.isEmpty else {
                continue
            }
            guard let blocker = firstBlockerOnSegment(start: start, end: end, blockers: segmentHits) else {
                continue
            }
            return LegacyBlockerHit(segmentIndex: segmentIndex, blocker: blocker)
        }

        return nil
    }

    private static func firstBlockerOnSegment(
        start: CGPoint,
        end: CGPoint,
        blockers: [LegacyNodeBlocker]
    ) -> LegacyNodeBlocker? {
        if isHorizontalSegment(start: start, end: end) {
            if end.x >= start.x {
                return blockers.min { lhs, rhs in
                    lhs.bounds.minX < rhs.bounds.minX
                }
            }
            return blockers.max { lhs, rhs in
                lhs.bounds.maxX < rhs.bounds.maxX
            }
        }

        if end.y >= start.y {
            return blockers.min { lhs, rhs in
                lhs.bounds.minY < rhs.bounds.minY
            }
        }
        return blockers.max { lhs, rhs in
            lhs.bounds.maxY < rhs.bounds.maxY
        }
    }

    private static func legacyDetourRoutes(
        for route: PolylineRoute,
        hit: LegacyBlockerHit
    ) -> [PolylineRoute] {
        let points = route.points
        let start = points[hit.segmentIndex]
        let end = points[hit.segmentIndex + 1]
        var candidates: [PolylineRoute] = []

        if isHorizontalSegment(start: start, end: end) {
            let movingPositive = end.x >= start.x
            let entryX = movingPositive ? hit.blocker.bounds.minX : hit.blocker.bounds.maxX
            let exitX = movingPositive ? hit.blocker.bounds.maxX : hit.blocker.bounds.minX
            for detourY in [hit.blocker.bounds.minY, hit.blocker.bounds.maxY] {
                let replacement = [
                    start,
                    point(x: entryX, y: Double(start.y)),
                    point(x: entryX, y: detourY),
                    point(x: exitX, y: detourY),
                    point(x: exitX, y: Double(start.y)),
                    end,
                ]
                candidates.append(routeByReplacingSegment(route, at: hit.segmentIndex, replacement: replacement))

                let fullShiftReplacement = [
                    start,
                    point(x: Double(start.x), y: detourY),
                    point(x: Double(end.x), y: detourY),
                    end,
                ]
                candidates.append(
                    routeByReplacingSegment(route, at: hit.segmentIndex, replacement: fullShiftReplacement)
                )
            }
            return uniqueRoutes(candidates)
        }

        let movingPositive = end.y >= start.y
        let entryY = movingPositive ? hit.blocker.bounds.minY : hit.blocker.bounds.maxY
        let exitY = movingPositive ? hit.blocker.bounds.maxY : hit.blocker.bounds.minY
        for detourX in [hit.blocker.bounds.minX, hit.blocker.bounds.maxX] {
            let replacement = [
                start,
                point(x: Double(start.x), y: entryY),
                point(x: detourX, y: entryY),
                point(x: detourX, y: exitY),
                point(x: Double(start.x), y: exitY),
                end,
            ]
            candidates.append(routeByReplacingSegment(route, at: hit.segmentIndex, replacement: replacement))

            let fullShiftReplacement = [
                start,
                point(x: detourX, y: Double(start.y)),
                point(x: detourX, y: Double(end.y)),
                end,
            ]
            candidates.append(
                routeByReplacingSegment(route, at: hit.segmentIndex, replacement: fullShiftReplacement)
            )
        }
        return uniqueRoutes(candidates)
    }

    private static func routeByReplacingSegment(
        _ route: PolylineRoute,
        at segmentIndex: Int,
        replacement: [CGPoint]
    ) -> PolylineRoute {
        let points = route.points
        let updatedPoints =
            Array(points.prefix(segmentIndex))
            + replacement
            + Array(points.suffix(from: segmentIndex + 2))
        return simplifiedPolylineRoute(points: updatedPoints)
    }

    private static func simplifiedPolylineRoute(points: [CGPoint]) -> PolylineRoute {
        let simplifiedPoints = simplifiedPoints(points)
        precondition(simplifiedPoints.count >= 2, "Polyline route must contain at least two points")
        return PolylineRoute(
            start: simplifiedPoints[0],
            bendPoints: Array(simplifiedPoints.dropFirst().dropLast()),
            end: simplifiedPoints[simplifiedPoints.count - 1]
        )
    }

    private static func simplifiedPoints(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []

        for point in points {
            if let lastPoint = result.last, arePointsEqual(lastPoint, point) {
                continue
            }
            result.append(point)

            while result.count >= 3 {
                let pointA = result[result.count - 3]
                let pointB = result[result.count - 2]
                let pointC = result[result.count - 1]
                guard arePointsCollinear(pointA, pointB, pointC) else {
                    break
                }
                result.remove(at: result.count - 2)
            }
        }

        return result
    }

    private static func legacyRouteCost(route: PolylineRoute, baseRoute: PolylineRoute) -> Double {
        legacyRouteLength(route)
            + (Double(route.bendPoints.count) * legacyBendPenalty)
            + max(legacyRouteLength(route) - legacyRouteLength(baseRoute), 0)
    }

    private static func legacyRouteLength(_ route: PolylineRoute) -> Double {
        let points = route.points
        guard points.count >= 2 else {
            return 0
        }

        return (0..<(points.count - 1)).reduce(0) { partial, index in
            partial + distance(from: points[index], to: points[index + 1])
        }
    }

    private static func distance(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        abs(Double(rhs.x - lhs.x)) + abs(Double(rhs.y - lhs.y))
    }

    private static func legacyRouteHasSelfIntersection(_ route: PolylineRoute) -> Bool {
        let points = route.points
        guard points.count >= 4 else {
            return false
        }

        for firstIndex in 0..<(points.count - 1) {
            guard firstIndex + 2 < points.count - 1 else {
                continue
            }
            let firstStart = points[firstIndex]
            let firstEnd = points[firstIndex + 1]
            for secondIndex in (firstIndex + 2)..<(points.count - 1) {
                if firstIndex == 0, secondIndex == points.count - 2 {
                    continue
                }
                let secondStart = points[secondIndex]
                let secondEnd = points[secondIndex + 1]
                if segmentsIntersect(
                    startA: firstStart,
                    endA: firstEnd,
                    startB: secondStart,
                    endB: secondEnd
                ) {
                    return true
                }
            }
        }

        return false
    }

    private static func segmentsIntersect(
        startA: CGPoint,
        endA: CGPoint,
        startB: CGPoint,
        endB: CGPoint
    ) -> Bool {
        let firstIsHorizontal = isHorizontalSegment(start: startA, end: endA)
        let secondIsHorizontal = isHorizontalSegment(start: startB, end: endB)

        if firstIsHorizontal == secondIsHorizontal {
            if firstIsHorizontal {
                guard abs(Double(startA.y - startB.y)) < legacyEpsilon else {
                    return false
                }
                return overlapLength(
                    firstStart: Double(startA.x),
                    firstEnd: Double(endA.x),
                    secondStart: Double(startB.x),
                    secondEnd: Double(endB.x)
                ) > legacyEpsilon
            }

            guard abs(Double(startA.x - startB.x)) < legacyEpsilon else {
                return false
            }
            return overlapLength(
                firstStart: Double(startA.y),
                firstEnd: Double(endA.y),
                secondStart: Double(startB.y),
                secondEnd: Double(endB.y)
            ) > legacyEpsilon
        }

        let horizontalStart = firstIsHorizontal ? startA : startB
        let horizontalEnd = firstIsHorizontal ? endA : endB
        let verticalStart = firstIsHorizontal ? startB : startA
        let verticalEnd = firstIsHorizontal ? endB : endA
        let intersectionX = Double(verticalStart.x)
        let intersectionY = Double(horizontalStart.y)

        return rangeContains(
            intersectionX,
            start: Double(horizontalStart.x),
            end: Double(horizontalEnd.x)
        )
            && rangeContains(
                intersectionY,
                start: Double(verticalStart.y),
                end: Double(verticalEnd.y)
            )
    }

    private static func overlapLength(
        firstStart: Double,
        firstEnd: Double,
        secondStart: Double,
        secondEnd: Double
    ) -> Double {
        let firstLower = min(firstStart, firstEnd)
        let firstUpper = max(firstStart, firstEnd)
        let secondLower = min(secondStart, secondEnd)
        let secondUpper = max(secondStart, secondEnd)
        return min(firstUpper, secondUpper) - max(firstLower, secondLower)
    }

    private static func segmentIntersectsRect(
        start: CGPoint,
        end: CGPoint,
        rect: CanvasRect
    ) -> Bool {
        if isHorizontalSegment(start: start, end: end) {
            let y = Double(start.y)
            guard y > rect.minY, y < rect.maxY else {
                return false
            }
            return overlapLength(
                firstStart: Double(start.x),
                firstEnd: Double(end.x),
                secondStart: rect.minX,
                secondEnd: rect.maxX
            ) > legacyEpsilon
        }

        let x = Double(start.x)
        guard x > rect.minX, x < rect.maxX else {
            return false
        }
        return overlapLength(
            firstStart: Double(start.y),
            firstEnd: Double(end.y),
            secondStart: rect.minY,
            secondEnd: rect.maxY
        ) > legacyEpsilon
    }

    private static func isHorizontalSegment(start: CGPoint, end: CGPoint) -> Bool {
        abs(Double(start.y - end.y)) < legacyEpsilon
    }

    private static func rangeContains(_ value: Double, start: Double, end: Double) -> Bool {
        let lower = min(start, end) - legacyEpsilon
        let upper = max(start, end) + legacyEpsilon
        return value >= lower && value <= upper
    }

    private static func arePointsEqual(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
        abs(Double(lhs.x - rhs.x)) < legacyEpsilon && abs(Double(lhs.y - rhs.y)) < legacyEpsilon
    }

    private static func arePointsCollinear(_ lhs: CGPoint, _ mid: CGPoint, _ rhs: CGPoint) -> Bool {
        let area =
            (Double(mid.x - lhs.x) * Double(rhs.y - mid.y))
            - (Double(mid.y - lhs.y) * Double(rhs.x - mid.x))
        return abs(area) < legacyEpsilon
    }

    private static func point(x: Double, y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x), y: CGFloat(y))
    }

    private static func uniqueRoutes(_ routes: [PolylineRoute]) -> [PolylineRoute] {
        var seen: Set<String> = []
        var result: [PolylineRoute] = []

        for route in routes.sorted(by: isRouteSignatureBefore) {
            let signature = routeSignature(route: route)
            guard seen.insert(signature).inserted else {
                continue
            }
            result.append(route)
        }

        return result
    }
}
