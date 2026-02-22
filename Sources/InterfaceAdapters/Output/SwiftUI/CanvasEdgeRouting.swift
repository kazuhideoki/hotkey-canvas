// Background: Straight center-to-center edges overlap sibling nodes as child counts grow.
// Responsibility: Compute side-anchored branched routes so parent-child edges remain readable.
import Domain
import SwiftUI

/// Computes MindNode-like edge routes with a shared branch axis per parent node.
enum CanvasEdgeRouting {
    private static let minimumBranchGap: Double = 12
    private static let maximumBranchOffset: Double = 72
    private static let minimumBranchOffset: Double = 24
    private static let minimumLegLength: Double = 6
    private static let defaultCornerRadius: Double = 14
    private static let verticalPreferenceRatio: Double = 0.9

    /// Primary axis used for routing one edge.
    enum RouteAxis: Hashable {
        case horizontal
        case vertical
    }

    /// Geometric route information used to build a rounded edge path.
    struct RouteGeometry: Equatable {
        let axis: RouteAxis
        let startX: Double
        let startY: Double
        let branchCoordinate: Double
        let endX: Double
        let endY: Double
    }

    /// Parent+axis+direction key used for storing shared branch coordinates.
    struct BranchKey: Hashable {
        let parentNodeID: CanvasNodeID
        let axis: RouteAxis
        let direction: Int
    }

    /// Returns the shared branch coordinate for each parent node side.
    /// - Parameters:
    ///   - edges: Graph edges to route.
    ///   - nodesByID: Node lookup used for geometric calculations.
    /// - Returns: Mapping from parent/axis/direction to branch coordinate in canvas coordinates.
    static func branchCoordinateByParentAndDirection(
        edges: [CanvasEdge],
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> [BranchKey: Double] {
        let edgesByParent = Dictionary(grouping: edges, by: \.fromNodeID)
        var result: [BranchKey: Double] = [:]

        for (parentID, parentEdges) in edgesByParent {
            guard let parentNode = nodesByID[parentID] else {
                continue
            }
            for axis in [RouteAxis.horizontal, RouteAxis.vertical] {
                for direction in [-1.0, 1.0] {
                    guard
                        let branchCoordinate = branchCoordinate(
                            parentNode: parentNode,
                            parentEdges: parentEdges,
                            axis: axis,
                            direction: direction,
                            nodesByID: nodesByID
                        )
                    else {
                        continue
                    }
                    let key = BranchKey(
                        parentNodeID: parentID,
                        axis: axis,
                        direction: direction > 0 ? 1 : -1
                    )
                    result[key] = branchCoordinate
                }
            }
        }

        return result
    }

    /// Builds a rounded route path for a single edge.
    /// - Parameters:
    ///   - edge: Edge to route.
    ///   - nodesByID: Node lookup for endpoint geometry.
    ///   - branchCoordinateByParentAndDirection: Shared branch coordinate per parent/axis/direction.
    /// - Returns: Routed path or nil when endpoints are missing.
    static func path(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode],
        branchCoordinateByParentAndDirection: [BranchKey: Double]
    ) -> Path? {
        guard
            let geometry = routeGeometry(
                for: edge,
                nodesByID: nodesByID,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
            )
        else {
            return nil
        }

        return Path { path in
            let start = CGPoint(x: geometry.startX, y: geometry.startY)
            let end = CGPoint(x: geometry.endX, y: geometry.endY)
            path.move(to: start)

            switch geometry.axis {
            case .horizontal:
                addHorizontalPath(path: &path, geometry: geometry, end: end)
            case .vertical:
                addVerticalPath(path: &path, geometry: geometry, end: end)
            }
        }
    }

    /// Computes route geometry for one edge.
    /// - Parameters:
    ///   - edge: Edge to route.
    ///   - nodesByID: Node lookup for endpoint geometry.
    ///   - branchCoordinateByParentAndDirection: Shared branch coordinate per parent/axis/direction.
    /// - Returns: Route geometry or nil when endpoints are missing.
    static func routeGeometry(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode],
        branchCoordinateByParentAndDirection: [BranchKey: Double]
    ) -> RouteGeometry? {
        guard
            let parentNode = nodesByID[edge.fromNodeID],
            let childNode = nodesByID[edge.toNodeID]
        else {
            return nil
        }

        let axis = routeAxis(parentNode: parentNode, childNode: childNode)
        let direction = directionSign(for: axis, parentNode: parentNode, childNode: childNode)
        let directionKey = BranchKey(
            parentNodeID: edge.fromNodeID,
            axis: axis,
            direction: direction > 0 ? 1 : -1
        )

        let startCenterX = parentNode.bounds.x + (parentNode.bounds.width / 2)
        let startCenterY = parentNode.bounds.y + (parentNode.bounds.height / 2)
        let endCenterX = childNode.bounds.x + (childNode.bounds.width / 2)
        let endCenterY = childNode.bounds.y + (childNode.bounds.height / 2)
        let startX =
            if axis == .horizontal {
                edgeExitCoordinate(for: parentNode, axis: axis, direction: direction)
            } else {
                startCenterX
            }
        let endX =
            if axis == .horizontal {
                edgeEntryCoordinate(for: childNode, axis: axis, direction: direction)
            } else {
                endCenterX
            }
        let startY =
            if axis == .horizontal {
                startCenterY
            } else {
                edgeExitCoordinate(for: parentNode, axis: axis, direction: direction)
            }
        let endY =
            if axis == .horizontal {
                endCenterY
            } else {
                edgeEntryCoordinate(for: childNode, axis: axis, direction: direction)
            }

        let startCoordinate = axis == .horizontal ? startX : startY
        let endCoordinate = axis == .horizontal ? endX : endY
        let branchCoordinate = constrainBranchCoordinate(
            branchCoordinateByParentAndDirection[directionKey]
                ?? (startCoordinate + (direction * minimumBranchOffset)),
            start: startCoordinate,
            end: endCoordinate
        )

        return RouteGeometry(
            axis: axis,
            startX: startX,
            startY: startY,
            branchCoordinate: branchCoordinate,
            endX: endX,
            endY: endY
        )
    }
}

extension CanvasEdgeRouting {
    private static func routeAxis(
        parentNode: CanvasNode,
        childNode: CanvasNode
    ) -> RouteAxis {
        let childCenterX = childNode.bounds.x + (childNode.bounds.width / 2)
        let childCenterY = childNode.bounds.y + (childNode.bounds.height / 2)
        let parentCenterX = parentNode.bounds.x + (parentNode.bounds.width / 2)
        let parentCenterY = parentNode.bounds.y + (parentNode.bounds.height / 2)
        let deltaX = abs(childCenterX - parentCenterX)
        let deltaY = abs(childCenterY - parentCenterY)

        if deltaY >= (deltaX * verticalPreferenceRatio) {
            return .vertical
        }
        return .horizontal
    }

    private static func directionSign(
        for axis: RouteAxis,
        parentNode: CanvasNode,
        childNode: CanvasNode
    ) -> Double {
        let childCenterX = childNode.bounds.x + (childNode.bounds.width / 2)
        let childCenterY = childNode.bounds.y + (childNode.bounds.height / 2)
        let parentCenterX = parentNode.bounds.x + (parentNode.bounds.width / 2)
        let parentCenterY = parentNode.bounds.y + (parentNode.bounds.height / 2)
        switch axis {
        case .horizontal:
            return childCenterX >= parentCenterX ? 1 : -1
        case .vertical:
            return childCenterY >= parentCenterY ? 1 : -1
        }
    }

    private static func branchCoordinate(
        parentNode: CanvasNode,
        parentEdges: [CanvasEdge],
        axis: RouteAxis,
        direction: Double,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> Double? {
        let directionalEdges = parentEdges.filter { edge in
            guard let childNode = nodesByID[edge.toNodeID] else {
                return false
            }
            return
                routeAxis(parentNode: parentNode, childNode: childNode) == axis
                && directionSign(for: axis, parentNode: parentNode, childNode: childNode) == direction
        }
        guard !directionalEdges.isEmpty else {
            return nil
        }

        let exitCoordinate = edgeExitCoordinate(for: parentNode, axis: axis, direction: direction)
        let childEntryCoordinates = directionalEdges.compactMap { edge -> Double? in
            guard let childNode = nodesByID[edge.toNodeID] else {
                return nil
            }
            return edgeEntryCoordinate(for: childNode, axis: axis, direction: direction)
        }
        guard !childEntryCoordinates.isEmpty else {
            return nil
        }

        let closestChildEntryCoordinate =
            if direction > 0 {
                childEntryCoordinates.min() ?? exitCoordinate
            } else {
                childEntryCoordinates.max() ?? exitCoordinate
            }
        let available = abs(closestChildEntryCoordinate - exitCoordinate)
        let offset = max(
            minimumBranchOffset,
            min(maximumBranchOffset, available * 0.45)
        )
        let baseBranchCoordinate = exitCoordinate + (direction * offset)
        return constrainBranchCoordinate(
            baseBranchCoordinate,
            start: exitCoordinate,
            end: closestChildEntryCoordinate
        )
    }

    private static func edgeExitCoordinate(for node: CanvasNode, axis: RouteAxis, direction: Double) -> Double {
        switch axis {
        case .horizontal:
            return direction >= 0 ? node.bounds.x + node.bounds.width : node.bounds.x
        case .vertical:
            return direction >= 0 ? node.bounds.y + node.bounds.height : node.bounds.y
        }
    }

    private static func edgeEntryCoordinate(for node: CanvasNode, axis: RouteAxis, direction: Double) -> Double {
        switch axis {
        case .horizontal:
            return direction >= 0 ? node.bounds.x : node.bounds.x + node.bounds.width
        case .vertical:
            return direction >= 0 ? node.bounds.y : node.bounds.y + node.bounds.height
        }
    }

    private static func constrainBranchCoordinate(_ branch: Double, start: Double, end: Double) -> Double {
        if end >= start {
            let lower = start + minimumLegLength
            let upper = end - minimumBranchGap
            guard lower <= upper else {
                return start + ((end - start) / 2)
            }
            return min(max(branch, lower), upper)
        }

        let lower = end + minimumBranchGap
        let upper = start - minimumLegLength
        guard lower <= upper else {
            return start + ((end - start) / 2)
        }
        return min(max(branch, lower), upper)
    }

    private static func addHorizontalPath(path: inout Path, geometry: RouteGeometry, end: CGPoint) {
        let horizontal1 = abs(geometry.branchCoordinate - geometry.startX)
        let horizontal2 = abs(geometry.endX - geometry.branchCoordinate)
        let vertical = abs(geometry.endY - geometry.startY)
        let cornerRadius = min(
            defaultCornerRadius,
            horizontal1 / 2,
            horizontal2 / 2,
            vertical / 2
        )

        guard cornerRadius > 0 else {
            path.addLine(to: end)
            return
        }

        let xSignToBranch: Double = geometry.branchCoordinate >= geometry.startX ? 1 : -1
        let ySignToEnd: Double = geometry.endY >= geometry.startY ? 1 : -1
        let xSignToEnd: Double = geometry.endX >= geometry.branchCoordinate ? 1 : -1

        path.addLine(
            to: CGPoint(
                x: geometry.branchCoordinate - (xSignToBranch * cornerRadius),
                y: geometry.startY
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: geometry.branchCoordinate,
                y: geometry.startY + (ySignToEnd * cornerRadius)
            ),
            control: CGPoint(x: geometry.branchCoordinate, y: geometry.startY)
        )
        path.addLine(
            to: CGPoint(
                x: geometry.branchCoordinate,
                y: geometry.endY - (ySignToEnd * cornerRadius)
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: geometry.branchCoordinate + (xSignToEnd * cornerRadius),
                y: geometry.endY
            ),
            control: CGPoint(x: geometry.branchCoordinate, y: geometry.endY)
        )
        path.addLine(to: end)
    }

    private static func addVerticalPath(path: inout Path, geometry: RouteGeometry, end: CGPoint) {
        let vertical1 = abs(geometry.branchCoordinate - geometry.startY)
        let vertical2 = abs(geometry.endY - geometry.branchCoordinate)
        let horizontal = abs(geometry.endX - geometry.startX)
        let cornerRadius = min(
            defaultCornerRadius,
            vertical1 / 2,
            vertical2 / 2,
            horizontal / 2
        )

        guard cornerRadius > 0 else {
            path.addLine(to: end)
            return
        }

        let ySignToBranch: Double = geometry.branchCoordinate >= geometry.startY ? 1 : -1
        let xSignToEnd: Double = geometry.endX >= geometry.startX ? 1 : -1
        let ySignToEnd: Double = geometry.endY >= geometry.branchCoordinate ? 1 : -1

        path.addLine(
            to: CGPoint(
                x: geometry.startX,
                y: geometry.branchCoordinate - (ySignToBranch * cornerRadius)
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: geometry.startX + (xSignToEnd * cornerRadius),
                y: geometry.branchCoordinate
            ),
            control: CGPoint(x: geometry.startX, y: geometry.branchCoordinate)
        )
        path.addLine(
            to: CGPoint(
                x: geometry.endX - (xSignToEnd * cornerRadius),
                y: geometry.branchCoordinate
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: geometry.endX,
                y: geometry.branchCoordinate + (ySignToEnd * cornerRadius)
            ),
            control: CGPoint(x: geometry.endX, y: geometry.branchCoordinate)
        )
        path.addLine(to: end)
    }
}
