import CoreGraphics
import Domain

@testable import InterfaceAdapters

func makeLegacyPolylineNode(
    id: CanvasNodeID,
    x: Double,
    y: Double,
    width: Double,
    height: Double
) -> (CanvasNodeID, CanvasNode) {
    (
        id,
        CanvasNode(
            id: id,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: x, y: y, width: width, height: height)
        )
    )
}

func routeIntersectsNode(
    _ route: CanvasEdgeRouting.PolylineRoute,
    node: CanvasNode,
    padding: Double = 0
) -> Bool {
    let rect = paddedRect(for: node, padding: padding)
    let points = route.points
    guard points.count >= 2 else {
        return false
    }

    for index in 0..<(points.count - 1)
    where segmentIntersectsRect(start: points[index], end: points[index + 1], rect: rect) {
        return true
    }
    return false
}

func routesIntersect(
    _ lhs: CanvasEdgeRouting.PolylineRoute,
    _ rhs: CanvasEdgeRouting.PolylineRoute
) -> Bool {
    let lhsPoints = lhs.points
    let rhsPoints = rhs.points
    guard lhsPoints.count >= 2, rhsPoints.count >= 2 else {
        return false
    }

    for lhsIndex in 0..<(lhsPoints.count - 1) {
        let lhsStart = lhsPoints[lhsIndex]
        let lhsEnd = lhsPoints[lhsIndex + 1]
        for rhsIndex in 0..<(rhsPoints.count - 1) {
            let rhsStart = rhsPoints[rhsIndex]
            let rhsEnd = rhsPoints[rhsIndex + 1]
            if shareOnlyEndpoint(
                firstStart: lhsStart,
                firstEnd: lhsEnd,
                secondStart: rhsStart,
                secondEnd: rhsEnd
            ) {
                continue
            }
            if segmentsIntersect(
                firstStart: lhsStart,
                firstEnd: lhsEnd,
                secondStart: rhsStart,
                secondEnd: rhsEnd
            ) {
                return true
            }
        }
    }
    return false
}

func pointLiesOnRoute(
    _ route: CanvasEdgeRouting.PolylineRoute,
    point: CGPoint
) -> Bool {
    let points = route.points
    guard points.count >= 2 else {
        return false
    }

    for index in 0..<(points.count - 1)
    where pointLiesOnSegment(point: point, start: points[index], end: points[index + 1]) {
        return true
    }
    return false
}

private func paddedRect(for node: CanvasNode, padding: Double) -> CanvasRect {
    CanvasRect(
        minX: node.bounds.x - padding,
        minY: node.bounds.y - padding,
        width: node.bounds.width + (padding * 2),
        height: node.bounds.height + (padding * 2)
    )
}

private func segmentIntersectsRect(
    start: CGPoint,
    end: CGPoint,
    rect: CanvasRect
) -> Bool {
    if start.x == end.x {
        let x = Double(start.x)
        guard x > rect.minX, x < rect.maxX else {
            return false
        }
        let minY = min(Double(start.y), Double(end.y))
        let maxY = max(Double(start.y), Double(end.y))
        return max(minY, rect.minY) < min(maxY, rect.maxY)
    }

    let y = Double(start.y)
    guard y > rect.minY, y < rect.maxY else {
        return false
    }
    let minX = min(Double(start.x), Double(end.x))
    let maxX = max(Double(start.x), Double(end.x))
    return max(minX, rect.minX) < min(maxX, rect.maxX)
}

private func segmentsIntersect(
    firstStart: CGPoint,
    firstEnd: CGPoint,
    secondStart: CGPoint,
    secondEnd: CGPoint
) -> Bool {
    let epsilon = 0.0001
    let firstIsVertical = abs(firstStart.x - firstEnd.x) < epsilon
    let secondIsVertical = abs(secondStart.x - secondEnd.x) < epsilon

    if firstIsVertical == secondIsVertical {
        if firstIsVertical {
            guard abs(firstStart.x - secondStart.x) < epsilon else {
                return false
            }
            return overlapLength(
                firstStart: Double(firstStart.y),
                firstEnd: Double(firstEnd.y),
                secondStart: Double(secondStart.y),
                secondEnd: Double(secondEnd.y)
            ) > epsilon
        }

        guard abs(firstStart.y - secondStart.y) < epsilon else {
            return false
        }
        return overlapLength(
            firstStart: Double(firstStart.x),
            firstEnd: Double(firstEnd.x),
            secondStart: Double(secondStart.x),
            secondEnd: Double(secondEnd.x)
        ) > epsilon
    }

    let verticalStart = firstIsVertical ? firstStart : secondStart
    let verticalEnd = firstIsVertical ? firstEnd : secondEnd
    let horizontalStart = firstIsVertical ? secondStart : firstStart
    let horizontalEnd = firstIsVertical ? secondEnd : firstEnd
    let intersectionX = Double(verticalStart.x)
    let intersectionY = Double(horizontalStart.y)

    return rangeContains(
        intersectionX, start: Double(horizontalStart.x), end: Double(horizontalEnd.x), epsilon: epsilon)
        && rangeContains(intersectionY, start: Double(verticalStart.y), end: Double(verticalEnd.y), epsilon: epsilon)
}

private func shareOnlyEndpoint(
    firstStart: CGPoint,
    firstEnd: CGPoint,
    secondStart: CGPoint,
    secondEnd: CGPoint
) -> Bool {
    let sharedPoints = [firstStart, firstEnd].filter { point in
        pointsEqual(point, secondStart) || pointsEqual(point, secondEnd)
    }
    return sharedPoints.count == 1
}

private func overlapLength(
    firstStart: Double,
    firstEnd: Double,
    secondStart: Double,
    secondEnd: Double
) -> Double {
    min(max(firstStart, firstEnd), max(secondStart, secondEnd))
        - max(min(firstStart, firstEnd), min(secondStart, secondEnd))
}

private func rangeContains(_ value: Double, start: Double, end: Double, epsilon: Double) -> Bool {
    value >= min(start, end) - epsilon && value <= max(start, end) + epsilon
}

private func pointsEqual(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
    let epsilon = 0.0001
    return abs(lhs.x - rhs.x) < epsilon && abs(lhs.y - rhs.y) < epsilon
}

private func pointLiesOnSegment(
    point: CGPoint,
    start: CGPoint,
    end: CGPoint
) -> Bool {
    let epsilon = 0.0001
    if abs(start.x - end.x) < epsilon {
        guard abs(point.x - start.x) < epsilon else {
            return false
        }
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        return point.y >= minY - epsilon && point.y <= maxY + epsilon
    }

    guard abs(point.y - start.y) < epsilon else {
        return false
    }
    let minX = min(start.x, end.x)
    let maxX = max(start.x, end.x)
    return point.x >= minX - epsilon && point.x <= maxX + epsilon
}
