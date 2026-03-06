// Background: Straight center-to-center edges overlap sibling nodes as child counts grow.
// Responsibility: Compute side-anchored branched routes so parent-child edges remain readable.
// swiftlint:disable file_length
import Domain
import SwiftUI

/// Computes MindNode-like edge routes with a shared branch axis per parent node.
enum CanvasEdgeRouting {
    static let minimumBranchGap: Double = 12
    static let minimumLegLength: Double = 6
    static let verticalPreferenceRatio: Double = 0.9
    static let parallelLaneSpacing: Double = 14
    static let minimumAnchorInset: Double = 4
    static let curvedBaseOffset: Double = 14
    static let curvedOffsetPerLaneLevel: Double = 11
    static let curvedLaneGrowthExponent: Double = 1.35
    static let curvedMinHandleRatio: Double = 0.2
    static let curvedMaxHandleLength: Double = 160

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

    /// Tip/vector pair used for drawing edge arrowheads.
    struct EdgeTipVector {
        let tip: CGPoint
        let vector: CGVector
    }

    /// Endpoint coordinates derived from node anchors before branch bending.
    struct RouteEndpoints: Equatable {
        let startX: Double
        let startY: Double
        let endX: Double
        let endY: Double
    }

    /// Parent+axis+direction key used for storing shared branch coordinates.
    struct BranchKey: Hashable {
        let parentNodeID: CanvasNodeID
        let axis: RouteAxis
        let direction: Int
    }

    /// Node+axis+side key used for assigning non-overlapping anchors around one node side.
    struct AnchorBundleKey: Hashable {
        let nodeID: CanvasNodeID
        let axis: RouteAxis
        let direction: Int
    }

    /// Per-endpoint lane offsets for one edge.
    struct EdgeLaneOffsets: Equatable {
        let start: Double
        let end: Double

        static let zero = EdgeLaneOffsets(start: 0, end: 0)
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

    /// Returns per-endpoint lane offsets so edges sharing one node-side anchor do not overlap.
    /// - Parameters:
    ///   - edges: Graph edges to route.
    ///   - nodesByID: Node lookup used for route axis and direction resolution.
    /// - Returns: Mapping from edge identifier to start/end offsets.
    static func laneOffsetsByEdgeID(
        edges: [CanvasEdge],
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> [CanvasEdgeID: EdgeLaneOffsets] {
        var groupedRefsByAnchor: [AnchorBundleKey: [AnchorEdgeRef]] = [:]
        var laneOffsetsByEdgeID: [CanvasEdgeID: EdgeLaneOffsets] = [:]

        for edge in edges {
            guard
                let parentNode = nodesByID[edge.fromNodeID],
                let childNode = nodesByID[edge.toNodeID]
            else {
                continue
            }
            let axis = routeAxis(parentNode: parentNode, childNode: childNode)
            let direction = directionSign(for: axis, parentNode: parentNode, childNode: childNode)
            let startDirection = direction > 0 ? 1 : -1
            let endDirection = -startDirection
            let startKey = AnchorBundleKey(nodeID: edge.fromNodeID, axis: axis, direction: startDirection)
            let endKey = AnchorBundleKey(nodeID: edge.toNodeID, axis: axis, direction: endDirection)
            let counterpartStartCoordinate = counterpartCoordinate(for: childNode, axis: axis)
            let counterpartEndCoordinate = counterpartCoordinate(for: parentNode, axis: axis)
            groupedRefsByAnchor[startKey, default: []].append(
                AnchorEdgeRef(
                    edgeID: edge.id,
                    kind: .start,
                    counterpartCoordinate: counterpartStartCoordinate
                )
            )
            groupedRefsByAnchor[endKey, default: []].append(
                AnchorEdgeRef(
                    edgeID: edge.id,
                    kind: .end,
                    counterpartCoordinate: counterpartEndCoordinate
                )
            )
            laneOffsetsByEdgeID[edge.id] = .zero
        }

        for key in groupedRefsByAnchor.keys.sorted(by: isAnchorBundleKeyOrdered) {
            guard let refs = groupedRefsByAnchor[key] else {
                continue
            }
            let sortedRefs = refs.sorted(by: isAnchorEdgeRefOrdered)
            guard sortedRefs.count > 1 else {
                continue
            }

            let centerIndex = Double(sortedRefs.count - 1) / 2
            for (index, ref) in sortedRefs.enumerated() {
                let laneOffset = (Double(index) - centerIndex) * parallelLaneSpacing
                let current = laneOffsetsByEdgeID[ref.edgeID] ?? .zero
                switch ref.kind {
                case .start:
                    laneOffsetsByEdgeID[ref.edgeID] = EdgeLaneOffsets(start: laneOffset, end: current.end)
                case .end:
                    laneOffsetsByEdgeID[ref.edgeID] = EdgeLaneOffsets(start: current.start, end: laneOffset)
                }
            }
        }

        return laneOffsetsByEdgeID
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
        branchCoordinateByParentAndDirection: [BranchKey: Double],
        laneOffsetsByEdgeID: [CanvasEdgeID: EdgeLaneOffsets] = [:],
        edgeShapeStyle: CanvasAreaEdgeShapeStyle
    ) -> Path? {
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

        return Path { path in
            let start = CGPoint(x: geometry.startX, y: geometry.startY)
            let end = CGPoint(x: geometry.endX, y: geometry.endY)
            path.move(to: start)
            switch edgeShapeStyle {
            case .legacy:
                addLegacyPathSegments(path: &path, geometry: geometry, end: end)
            case .straight:
                path.addLine(to: end)
            case .curved:
                let laneOffsets = curveLaneOffsets(for: edge.id, laneOffsetsByEdgeID: laneOffsetsByEdgeID)
                let curve = curvedGeometry(routeGeometry: geometry, laneOffsets: laneOffsets)
                path.addCurve(to: end, control1: curve.control1, control2: curve.control2)
            }
        }
    }

    /// Computes arrow tip and tangent vector for the specified edge style.
    static func edgeTipAndVector(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode],
        branchCoordinateByParentAndDirection: [BranchKey: Double],
        laneOffsetsByEdgeID: [CanvasEdgeID: EdgeLaneOffsets] = [:],
        edgeShapeStyle: CanvasAreaEdgeShapeStyle
    ) -> EdgeTipVector? {
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
        case .legacy:
            return legacyEdgeTipAndVector(edge: edge, routeGeometry: geometry)
        case .straight:
            return straightEdgeTipAndVector(edge: edge, routeGeometry: geometry)
        case .curved:
            let laneOffsets = curveLaneOffsets(for: edge.id, laneOffsetsByEdgeID: laneOffsetsByEdgeID)
            let curve = curvedGeometry(routeGeometry: geometry, laneOffsets: laneOffsets)
            return curvedEdgeTipAndVector(edge: edge, routeGeometry: geometry, curve: curve)
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
        branchCoordinateByParentAndDirection: [BranchKey: Double],
        laneOffsetsByEdgeID: [CanvasEdgeID: EdgeLaneOffsets] = [:]
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
        let laneOffsets = laneOffsetsByEdgeID[edge.id] ?? .zero
        let endpoints = routeEndpoints(
            axis: axis,
            direction: direction,
            parentNode: parentNode,
            childNode: childNode,
            laneOffsets: laneOffsets
        )
        let startCoordinate = axis == .horizontal ? endpoints.startX : endpoints.startY
        let endCoordinate = axis == .horizontal ? endpoints.endX : endpoints.endY
        let branchLaneOffset = laneOffsets.start
        let branchCoordinate = constrainBranchCoordinate(
            (branchCoordinateByParentAndDirection[directionKey]
                ?? (startCoordinate + ((endCoordinate - startCoordinate) / 2))) + branchLaneOffset,
            start: startCoordinate,
            end: endCoordinate
        )

        return RouteGeometry(
            axis: axis,
            startX: endpoints.startX,
            startY: endpoints.startY,
            branchCoordinate: branchCoordinate,
            endX: endpoints.endX,
            endY: endpoints.endY
        )
    }
}

extension CanvasEdgeRouting {
    private enum AnchorEdgeKind {
        case start
        case end
    }

    private struct AnchorEdgeRef {
        let edgeID: CanvasEdgeID
        let kind: AnchorEdgeKind
        let counterpartCoordinate: Double
    }

    private static func isAnchorBundleKeyOrdered(_ lhs: AnchorBundleKey, _ rhs: AnchorBundleKey) -> Bool {
        if lhs.nodeID.rawValue != rhs.nodeID.rawValue {
            return lhs.nodeID.rawValue < rhs.nodeID.rawValue
        }
        if lhs.axis != rhs.axis {
            return lhs.axis == .horizontal
        }
        if lhs.direction != rhs.direction {
            return lhs.direction < rhs.direction
        }
        return false
    }

    private static func isAnchorEdgeRefOrdered(_ lhs: AnchorEdgeRef, _ rhs: AnchorEdgeRef) -> Bool {
        if lhs.counterpartCoordinate != rhs.counterpartCoordinate {
            return lhs.counterpartCoordinate < rhs.counterpartCoordinate
        }
        if lhs.edgeID.rawValue != rhs.edgeID.rawValue {
            return lhs.edgeID.rawValue < rhs.edgeID.rawValue
        }
        switch (lhs.kind, rhs.kind) {
        case (.start, .end):
            return true
        case (.end, .start):
            return false
        default:
            return false
        }
    }

    private static func curveLaneOffsets(
        for edgeID: CanvasEdgeID,
        laneOffsetsByEdgeID: [CanvasEdgeID: EdgeLaneOffsets]
    ) -> EdgeLaneOffsets {
        laneOffsetsByEdgeID[edgeID] ?? .zero
    }

    private static func counterpartCoordinate(for node: CanvasNode, axis: RouteAxis) -> Double {
        axis == .horizontal
            ? node.bounds.y + (node.bounds.height / 2)
            : node.bounds.x + (node.bounds.width / 2)
    }

    private static func laneAdjustedCoordinate(
        for node: CanvasNode,
        axis: RouteAxis,
        baseCoordinate: Double,
        laneOffset: Double
    ) -> Double {
        let desiredCoordinate = baseCoordinate + laneOffset
        switch axis {
        case .horizontal:
            let lower = node.bounds.y + minimumAnchorInset
            let upper = node.bounds.y + node.bounds.height - minimumAnchorInset
            guard lower <= upper else {
                return baseCoordinate
            }
            return min(max(desiredCoordinate, lower), upper)
        case .vertical:
            let lower = node.bounds.x + minimumAnchorInset
            let upper = node.bounds.x + node.bounds.width - minimumAnchorInset
            guard lower <= upper else {
                return baseCoordinate
            }
            return min(max(desiredCoordinate, lower), upper)
        }
    }

    private static func routeEndpoints(
        axis: RouteAxis,
        direction: Double,
        parentNode: CanvasNode,
        childNode: CanvasNode,
        laneOffsets: EdgeLaneOffsets
    ) -> RouteEndpoints {
        let parentCenterX = parentNode.bounds.x + (parentNode.bounds.width / 2)
        let parentCenterY = parentNode.bounds.y + (parentNode.bounds.height / 2)
        let childCenterX = childNode.bounds.x + (childNode.bounds.width / 2)
        let childCenterY = childNode.bounds.y + (childNode.bounds.height / 2)

        let startX =
            axis == .horizontal
            ? edgeExitCoordinate(for: parentNode, axis: axis, direction: direction)
            : laneAdjustedCoordinate(
                for: parentNode, axis: axis, baseCoordinate: parentCenterX, laneOffset: laneOffsets.start)
        let startY =
            axis == .horizontal
            ? laneAdjustedCoordinate(
                for: parentNode, axis: axis, baseCoordinate: parentCenterY, laneOffset: laneOffsets.start)
            : edgeExitCoordinate(for: parentNode, axis: axis, direction: direction)
        let endX =
            axis == .horizontal
            ? edgeEntryCoordinate(for: childNode, axis: axis, direction: direction)
            : laneAdjustedCoordinate(
                for: childNode, axis: axis, baseCoordinate: childCenterX, laneOffset: laneOffsets.end)
        let endY =
            axis == .horizontal
            ? laneAdjustedCoordinate(
                for: childNode, axis: axis, baseCoordinate: childCenterY, laneOffset: laneOffsets.end)
            : edgeEntryCoordinate(for: childNode, axis: axis, direction: direction)

        return RouteEndpoints(startX: startX, startY: startY, endX: endX, endY: endY)
    }

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
        let baseBranchCoordinate = exitCoordinate + ((closestChildEntryCoordinate - exitCoordinate) / 2)
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

    private static func addLegacyPathSegments(path: inout Path, geometry: RouteGeometry, end: CGPoint) {
        switch geometry.axis {
        case .horizontal:
            path.addLine(to: CGPoint(x: geometry.branchCoordinate, y: geometry.startY))
            path.addLine(to: CGPoint(x: geometry.branchCoordinate, y: geometry.endY))
            path.addLine(to: end)
        case .vertical:
            path.addLine(to: CGPoint(x: geometry.startX, y: geometry.branchCoordinate))
            path.addLine(to: CGPoint(x: geometry.endX, y: geometry.branchCoordinate))
            path.addLine(to: end)
        }
    }

    private static func legacyEdgeTipAndVector(
        edge: CanvasEdge,
        routeGeometry: RouteGeometry
    ) -> EdgeTipVector {
        let start = CGPoint(x: routeGeometry.startX, y: routeGeometry.startY)
        let end = CGPoint(x: routeGeometry.endX, y: routeGeometry.endY)
        if edge.directionality == .fromTo {
            let previousPoint = legacyPreviousPointBeforeEnd(routeGeometry: routeGeometry)
            return EdgeTipVector(
                tip: end,
                vector: CGVector(dx: end.x - previousPoint.x, dy: end.y - previousPoint.y)
            )
        }
        if edge.directionality == .toFrom {
            let nextPoint = legacyNextPointAfterStart(routeGeometry: routeGeometry)
            return EdgeTipVector(
                tip: start,
                vector: CGVector(dx: start.x - nextPoint.x, dy: start.y - nextPoint.y)
            )
        }
        return EdgeTipVector(tip: end, vector: CGVector(dx: 0, dy: 0))
    }
    private static func legacyNextPointAfterStart(routeGeometry: RouteGeometry) -> CGPoint {
        switch routeGeometry.axis {
        case .horizontal:
            return CGPoint(x: routeGeometry.branchCoordinate, y: routeGeometry.startY)
        case .vertical:
            return CGPoint(x: routeGeometry.startX, y: routeGeometry.branchCoordinate)
        }
    }
    private static func legacyPreviousPointBeforeEnd(routeGeometry: RouteGeometry) -> CGPoint {
        switch routeGeometry.axis {
        case .horizontal:
            return CGPoint(x: routeGeometry.branchCoordinate, y: routeGeometry.endY)
        case .vertical:
            return CGPoint(x: routeGeometry.endX, y: routeGeometry.branchCoordinate)
        }
    }
}
// swiftlint:enable file_length
