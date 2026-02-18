import Foundation

// Background: Area collision resolution now supports convex hull outlines in addition to rectangles.
// Responsibility: Provide geometry primitives for hull generation, SAT overlap checks, and separation vectors.
extension CanvasAreaLayoutService {
    static func makeShape(
        for nodeIDs: Set<CanvasNodeID>,
        in graph: CanvasGraph,
        shapeKind: CanvasAreaShapeKind
    ) -> CanvasAreaShape {
        switch shapeKind {
        case .rectangle:
            return .rectangle
        case .convexHull:
            let points =
                nodeIDs
                .sorted { $0.rawValue < $1.rawValue }
                .compactMap { graph.nodesByID[$0] }
                .flatMap { node in
                    makeNodeCornerPoints(from: node.bounds)
                }
            let hull = makeConvexHull(from: points)
            guard hull.count >= 3 else {
                return .rectangle
            }
            return .convexHull(vertices: hull)
        }
    }

    static func makeNodeCornerPoints(from bounds: CanvasBounds) -> [CanvasPoint] {
        let minX = bounds.x
        let minY = bounds.y
        let maxX = bounds.x + bounds.width
        let maxY = bounds.y + bounds.height

        return [
            CanvasPoint(x: minX, y: minY),
            CanvasPoint(x: maxX, y: minY),
            CanvasPoint(x: maxX, y: maxY),
            CanvasPoint(x: minX, y: maxY),
        ]
    }

    static func makeConvexHull(from points: [CanvasPoint]) -> [CanvasPoint] {
        let uniqueSortedPoints = Array(Set(points)).sorted { lhs, rhs in
            if lhs.x == rhs.x {
                return lhs.y < rhs.y
            }
            return lhs.x < rhs.x
        }

        guard uniqueSortedPoints.count > 1 else {
            return uniqueSortedPoints
        }

        var lower: [CanvasPoint] = []
        for point in uniqueSortedPoints {
            while lower.count >= 2,
                crossProduct(lower[lower.count - 2], lower[lower.count - 1], point) <= numericEpsilon
            {
                lower.removeLast()
            }
            lower.append(point)
        }

        var upper: [CanvasPoint] = []
        for point in uniqueSortedPoints.reversed() {
            while upper.count >= 2,
                crossProduct(upper[upper.count - 2], upper[upper.count - 1], point) <= numericEpsilon
            {
                upper.removeLast()
            }
            upper.append(point)
        }

        if !lower.isEmpty {
            lower.removeLast()
        }
        if !upper.isEmpty {
            upper.removeLast()
        }
        return lower + upper
    }

    static func areasOverlap(
        _ lhs: AreaOutline,
        _ rhs: AreaOutline,
        spacing: Double
    ) -> Bool {
        let halfSpacing = max(0, spacing) / 2
        let expandedLHSBounds = lhs.bounds.expanded(horizontal: halfSpacing, vertical: halfSpacing)
        let expandedRHSBounds = rhs.bounds.expanded(horizontal: halfSpacing, vertical: halfSpacing)
        guard expandedLHSBounds.intersects(expandedRHSBounds) else {
            return false
        }

        if case .rectangle = lhs.shape, case .rectangle = rhs.shape {
            return true
        }

        let lhsPolygon = polygonPoints(for: lhs)
        let rhsPolygon = polygonPoints(for: rhs)
        return convexPolygonsOverlap(lhsPolygon, rhsPolygon, spacing: spacing)
    }

    static func requiredSeparation(
        moving: AreaOutline,
        fixed: AreaOutline,
        spacing: Double,
        tieBreakDirection: Double
    ) -> CanvasTranslation {
        let overlapX = projectionOverlap(
            moving: moving,
            fixed: fixed,
            axis: CanvasPoint(x: 1, y: 0),
            spacing: spacing
        )
        let overlapY = projectionOverlap(
            moving: moving,
            fixed: fixed,
            axis: CanvasPoint(x: 0, y: 1),
            spacing: spacing
        )
        guard overlapX > 0, overlapY > 0 else {
            return .zero
        }

        var directionX = moving.bounds.centerX - fixed.bounds.centerX
        var directionY = moving.bounds.centerY - fixed.bounds.centerY
        if abs(directionX) <= numericEpsilon, abs(directionY) <= numericEpsilon {
            directionX = tieBreakDirection >= 0 ? 1 : -1
            directionY = 0
        }

        if abs(directionX) >= abs(directionY) {
            let moveSignX: Double = directionX >= 0 ? 1 : -1
            return CanvasTranslation(dx: moveSignX * overlapX, dy: 0)
        }

        let moveSignY: Double = directionY >= 0 ? 1 : -1
        return CanvasTranslation(dx: 0, dy: moveSignY * overlapY)
    }

    static func translateShape(_ shape: CanvasAreaShape, dx: Double, dy: Double) -> CanvasAreaShape {
        switch shape {
        case .rectangle:
            return .rectangle
        case .convexHull(let vertices):
            return .convexHull(
                vertices: vertices.map { point in
                    CanvasPoint(x: point.x + dx, y: point.y + dy)
                }
            )
        }
    }

    private static func polygonPoints(for outline: AreaOutline) -> [CanvasPoint] {
        switch outline.shape {
        case .rectangle:
            return [
                CanvasPoint(x: outline.bounds.minX, y: outline.bounds.minY),
                CanvasPoint(x: outline.bounds.maxX, y: outline.bounds.minY),
                CanvasPoint(x: outline.bounds.maxX, y: outline.bounds.maxY),
                CanvasPoint(x: outline.bounds.minX, y: outline.bounds.maxY),
            ]
        case .convexHull(let vertices):
            guard vertices.count >= 3 else {
                return [
                    CanvasPoint(x: outline.bounds.minX, y: outline.bounds.minY),
                    CanvasPoint(x: outline.bounds.maxX, y: outline.bounds.minY),
                    CanvasPoint(x: outline.bounds.maxX, y: outline.bounds.maxY),
                    CanvasPoint(x: outline.bounds.minX, y: outline.bounds.maxY),
                ]
            }
            return vertices
        }
    }

    private static func convexPolygonsOverlap(
        _ lhs: [CanvasPoint],
        _ rhs: [CanvasPoint],
        spacing: Double
    ) -> Bool {
        let halfSpacing = max(0, spacing) / 2
        let axes = separatingAxes(for: lhs) + separatingAxes(for: rhs)

        for axis in axes {
            let lhsProjection = project(points: lhs, onto: axis)
            let rhsProjection = project(points: rhs, onto: axis)
            let expandedLHS = (min: lhsProjection.min - halfSpacing, max: lhsProjection.max + halfSpacing)
            let expandedRHS = (min: rhsProjection.min - halfSpacing, max: rhsProjection.max + halfSpacing)
            let overlap = min(expandedLHS.max, expandedRHS.max) - max(expandedLHS.min, expandedRHS.min)
            if overlap <= numericEpsilon {
                return false
            }
        }

        return true
    }

    private static func separatingAxes(for polygon: [CanvasPoint]) -> [CanvasPoint] {
        guard polygon.count >= 2 else {
            return []
        }

        var axes: [CanvasPoint] = []
        for index in polygon.indices {
            let nextIndex = (index + 1) % polygon.count
            let edgeX = polygon[nextIndex].x - polygon[index].x
            let edgeY = polygon[nextIndex].y - polygon[index].y
            let length = sqrt((edgeX * edgeX) + (edgeY * edgeY))
            guard length > numericEpsilon else {
                continue
            }
            axes.append(CanvasPoint(x: -edgeY / length, y: edgeX / length))
        }
        return axes
    }

    private static func projectionOverlap(
        moving: AreaOutline,
        fixed: AreaOutline,
        axis: CanvasPoint,
        spacing: Double
    ) -> Double {
        let movingProjection = project(points: polygonPoints(for: moving), onto: axis)
        let fixedProjection = project(points: polygonPoints(for: fixed), onto: axis)

        let halfSpacing = max(0, spacing) / 2
        let expandedMoving = (min: movingProjection.min - halfSpacing, max: movingProjection.max + halfSpacing)
        let expandedFixed = (min: fixedProjection.min - halfSpacing, max: fixedProjection.max + halfSpacing)
        return min(expandedMoving.max, expandedFixed.max) - max(expandedMoving.min, expandedFixed.min)
    }

    private static func project(points: [CanvasPoint], onto axis: CanvasPoint) -> (min: Double, max: Double) {
        guard let firstPoint = points.first else {
            return (0, 0)
        }

        var minProjection = dotProduct(firstPoint, axis)
        var maxProjection = minProjection

        for point in points.dropFirst() {
            let projection = dotProduct(point, axis)
            minProjection = min(minProjection, projection)
            maxProjection = max(maxProjection, projection)
        }

        return (minProjection, maxProjection)
    }

    private static func crossProduct(_ origin: CanvasPoint, _ first: CanvasPoint, _ second: CanvasPoint) -> Double {
        let firstX = first.x - origin.x
        let firstY = first.y - origin.y
        let secondX = second.x - origin.x
        let secondY = second.y - origin.y
        return (firstX * secondY) - (firstY * secondX)
    }

    private static func dotProduct(_ point: CanvasPoint, _ axis: CanvasPoint) -> Double {
        (point.x * axis.x) + (point.y * axis.y)
    }
}
