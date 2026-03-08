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
    static let routeSelectionNodeAvoidancePadding: Double = 18
    static let rerouteOutwardBranchOffsets: [Double] = [24, 48, 80, 120, 180, 260, 360]
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

    /// One candidate anchor side on a node boundary.
    enum AnchorSide: Hashable {
        case left
        case right
        case top
        case bottom
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
                let legacyRoute = legacyPolylineRoute(for: edge, routeGeometry: geometry, nodesByID: nodesByID)
                addPolylinePathSegments(path: &path, route: legacyRoute)
            case .straight:
                path.addLine(to: end)
            case .curved:
                let laneOffsets = curveLaneOffsets(for: edge.id, laneOffsetsByEdgeID: laneOffsetsByEdgeID)
                let curve = resolvedCurvedGeometry(
                    for: edge,
                    routeGeometry: geometry,
                    nodesByID: nodesByID,
                    laneOffsets: laneOffsets
                )
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
            let legacyRoute = legacyPolylineRoute(for: edge, routeGeometry: geometry, nodesByID: nodesByID)
            return legacyEdgeTipAndVector(edge: edge, polylineRoute: legacyRoute)
        case .straight:
            return straightEdgeTipAndVector(edge: edge, routeGeometry: geometry)
        case .curved:
            let laneOffsets = curveLaneOffsets(for: edge.id, laneOffsetsByEdgeID: laneOffsetsByEdgeID)
            let curve = resolvedCurvedGeometry(
                for: edge,
                routeGeometry: geometry,
                nodesByID: nodesByID,
                laneOffsets: laneOffsets
            )
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
        let laneOffsets = laneOffsetsByEdgeID[edge.id] ?? .zero
        let defaultTemplate = defaultRouteTemplate(axis: axis, direction: direction)
        guard
            let defaultGeometry = routeGeometry(
                edge: edge,
                parentNode: parentNode,
                childNode: childNode,
                template: defaultTemplate,
                laneOffsets: laneOffsets,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
            )
        else {
            return nil
        }

        let blockers = routingNodeBlockers(for: edge, nodesByID: nodesByID)
        guard blockerHitCount(for: legacyPolylineRoute(routeGeometry: defaultGeometry), blockers: blockers) > 0 else {
            return defaultGeometry
        }

        let candidates = rerouteTemplates(defaultAxis: axis, defaultDirection: direction).flatMap { template in
            routeCandidates(
                edge: edge,
                parentNode: parentNode,
                childNode: childNode,
                template: template,
                laneOffsets: laneOffsets,
                blockers: blockers,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
            )
        }

        return candidates.min(by: isRouteCandidateBetter)?.geometry ?? defaultGeometry
    }
}

extension CanvasEdgeRouting.BranchKey {
    func hash(into hasher: inout Hasher) {
        hasher.combine(parentNodeID)
        hasher.combine(axis)
        hasher.combine(direction)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.parentNodeID == rhs.parentNodeID
            && lhs.axis == rhs.axis
            && lhs.direction == rhs.direction
    }
}

extension CanvasEdgeRouting {
    private struct RoutingNodeBlocker {
        let bounds: CanvasRect
    }

    private struct RouteTemplate {
        let axis: RouteAxis
        let startSide: AnchorSide
        let endSide: AnchorSide
        let preferencePenalty: Double
        let branchLookupDirection: Int?
    }

    private struct RouteCandidate {
        let geometry: RouteGeometry
        let route: PolylineRoute
        let blockerHitCount: Int
        let cost: Double
    }

    private enum AnchorEdgeKind {
        case start
        case end
    }

    private struct AnchorEdgeRef {
        let edgeID: CanvasEdgeID
        let kind: AnchorEdgeKind
        let counterpartCoordinate: Double
    }

    private static func routingNodeBlockers(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> [RoutingNodeBlocker] {
        nodesByID.compactMap { nodeID, node in
            guard nodeID != edge.fromNodeID, nodeID != edge.toNodeID else {
                return nil
            }
            return RoutingNodeBlocker(
                bounds: CanvasRect(
                    minX: node.bounds.x - routeSelectionNodeAvoidancePadding,
                    minY: node.bounds.y - routeSelectionNodeAvoidancePadding,
                    width: node.bounds.width + (routeSelectionNodeAvoidancePadding * 2),
                    height: node.bounds.height + (routeSelectionNodeAvoidancePadding * 2)
                )
            )
        }
    }

    private static func routeGeometry(
        edge: CanvasEdge,
        parentNode: CanvasNode,
        childNode: CanvasNode,
        template: RouteTemplate,
        laneOffsets: EdgeLaneOffsets,
        branchCoordinateByParentAndDirection: [BranchKey: Double]
    ) -> RouteGeometry? {
        let endpoints = routeEndpoints(
            startSide: template.startSide,
            endSide: template.endSide,
            parentNode: parentNode,
            childNode: childNode,
            laneOffsets: laneOffsets
        )
        return RouteGeometry(
            axis: template.axis,
            startX: endpoints.startX,
            startY: endpoints.startY,
            branchCoordinate: templateBranchCoordinate(
                edge: edge,
                template: template,
                endpoints: endpoints,
                laneOffsets: laneOffsets,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
            ),
            endX: endpoints.endX,
            endY: endpoints.endY
        )
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
        startSide: AnchorSide,
        endSide: AnchorSide,
        parentNode: CanvasNode,
        childNode: CanvasNode,
        laneOffsets: EdgeLaneOffsets
    ) -> RouteEndpoints {
        let parentCenterX = parentNode.bounds.x + (parentNode.bounds.width / 2)
        let parentCenterY = parentNode.bounds.y + (parentNode.bounds.height / 2)
        let childCenterX = childNode.bounds.x + (childNode.bounds.width / 2)
        let childCenterY = childNode.bounds.y + (childNode.bounds.height / 2)

        let startX = anchorX(for: startSide, node: parentNode, centerX: parentCenterX, laneOffset: laneOffsets.start)
        let startY = anchorY(for: startSide, node: parentNode, centerY: parentCenterY, laneOffset: laneOffsets.start)
        let endX = anchorX(for: endSide, node: childNode, centerX: childCenterX, laneOffset: laneOffsets.end)
        let endY = anchorY(for: endSide, node: childNode, centerY: childCenterY, laneOffset: laneOffsets.end)

        return RouteEndpoints(startX: startX, startY: startY, endX: endX, endY: endY)
    }

    private static func anchorX(
        for side: AnchorSide,
        node: CanvasNode,
        centerX: Double,
        laneOffset: Double
    ) -> Double {
        switch side {
        case .left:
            return node.bounds.x
        case .right:
            return node.bounds.x + node.bounds.width
        case .top, .bottom:
            return laneAdjustedCoordinate(for: node, axis: .vertical, baseCoordinate: centerX, laneOffset: laneOffset)
        }
    }

    private static func anchorY(
        for side: AnchorSide,
        node: CanvasNode,
        centerY: Double,
        laneOffset: Double
    ) -> Double {
        switch side {
        case .top:
            return node.bounds.y
        case .bottom:
            return node.bounds.y + node.bounds.height
        case .left, .right:
            return laneAdjustedCoordinate(
                for: node,
                axis: .horizontal,
                baseCoordinate: centerY,
                laneOffset: laneOffset
            )
        }
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

    private static func defaultRouteTemplate(axis: RouteAxis, direction: Double) -> RouteTemplate {
        switch axis {
        case .horizontal:
            return direction >= 0
                ? RouteTemplate(
                    axis: .horizontal, startSide: .right, endSide: .left, preferencePenalty: 0,
                    branchLookupDirection: 1)
                : RouteTemplate(
                    axis: .horizontal, startSide: .left, endSide: .right, preferencePenalty: 0,
                    branchLookupDirection: -1)
        case .vertical:
            return direction >= 0
                ? RouteTemplate(
                    axis: .vertical, startSide: .bottom, endSide: .top, preferencePenalty: 0,
                    branchLookupDirection: 1)
                : RouteTemplate(
                    axis: .vertical, startSide: .top, endSide: .bottom, preferencePenalty: 0,
                    branchLookupDirection: -1)
        }
    }

    private static func rerouteTemplates(defaultAxis: RouteAxis, defaultDirection: Double) -> [RouteTemplate] {
        let defaultTemplate = defaultRouteTemplate(axis: defaultAxis, direction: defaultDirection)
        let reverseTemplate = defaultRouteTemplate(axis: defaultAxis, direction: -defaultDirection)
        let horizontalSameSideTemplates = [
            RouteTemplate(
                axis: .horizontal, startSide: .left, endSide: .left, preferencePenalty: 40,
                branchLookupDirection: nil),
            RouteTemplate(
                axis: .horizontal, startSide: .right, endSide: .right, preferencePenalty: 40,
                branchLookupDirection: nil),
        ]
        let verticalSameSideTemplates = [
            RouteTemplate(
                axis: .vertical, startSide: .top, endSide: .top, preferencePenalty: 30,
                branchLookupDirection: nil),
            RouteTemplate(
                axis: .vertical, startSide: .bottom, endSide: .bottom, preferencePenalty: 30,
                branchLookupDirection: nil),
        ]

        let orderedSameSideTemplates =
            switch defaultAxis {
            case .horizontal:
                verticalSameSideTemplates + horizontalSameSideTemplates
            case .vertical:
                horizontalSameSideTemplates + verticalSameSideTemplates
            }

        return [defaultTemplate] + orderedSameSideTemplates + [
            RouteTemplate(
                axis: reverseTemplate.axis,
                startSide: reverseTemplate.startSide,
                endSide: reverseTemplate.endSide,
                preferencePenalty: 80,
                branchLookupDirection: reverseTemplate.branchLookupDirection
            )
        ]
    }

    private static func routeCandidates(
        edge: CanvasEdge,
        parentNode: CanvasNode,
        childNode: CanvasNode,
        template: RouteTemplate,
        laneOffsets: EdgeLaneOffsets,
        blockers: [RoutingNodeBlocker],
        branchCoordinateByParentAndDirection: [BranchKey: Double]
    ) -> [RouteCandidate] {
        routeGeometries(
            edge: edge,
            parentNode: parentNode,
            childNode: childNode,
            template: template,
            laneOffsets: laneOffsets,
            branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
        ).map { geometry in
            let route = legacyPolylineRoute(routeGeometry: geometry)
            let blockerHitCount = blockerHitCount(for: route, blockers: blockers)
            return RouteCandidate(
                geometry: geometry,
                route: route,
                blockerHitCount: blockerHitCount,
                cost: Double(blockerHitCount) * 10_000
                    + template.preferencePenalty
                    + sameSideTemplateBiasPenalty(template: template, laneOffsets: laneOffsets)
                    + polylineLength(route)
            )
        }
    }

    private static func routeGeometries(
        edge: CanvasEdge,
        parentNode: CanvasNode,
        childNode: CanvasNode,
        template: RouteTemplate,
        laneOffsets: EdgeLaneOffsets,
        branchCoordinateByParentAndDirection: [BranchKey: Double]
    ) -> [RouteGeometry] {
        guard
            let baseGeometry = routeGeometry(
                edge: edge,
                parentNode: parentNode,
                childNode: childNode,
                template: template,
                laneOffsets: laneOffsets,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
            )
        else {
            return []
        }
        guard template.startSide == template.endSide else {
            return [baseGeometry]
        }
        return rerouteOutwardBranchOffsets.map { offset in
            RouteGeometry(
                axis: baseGeometry.axis,
                startX: baseGeometry.startX,
                startY: baseGeometry.startY,
                branchCoordinate: outwardBranchCoordinate(
                    for: template.startSide,
                    geometry: baseGeometry,
                    offset: offset + laneOffsetForSameSideBranch(laneOffsets: laneOffsets)
                ),
                endX: baseGeometry.endX,
                endY: baseGeometry.endY
            )
        }
    }

    private static func templateBranchCoordinate(
        edge: CanvasEdge,
        template: RouteTemplate,
        endpoints: RouteEndpoints,
        laneOffsets: EdgeLaneOffsets,
        branchCoordinateByParentAndDirection: [BranchKey: Double]
    ) -> Double {
        if let direction = template.branchLookupDirection {
            let directionKey = BranchKey(
                parentNodeID: edge.fromNodeID,
                axis: template.axis,
                direction: direction
            )
            let startCoordinate = template.axis == .horizontal ? endpoints.startX : endpoints.startY
            let endCoordinate = template.axis == .horizontal ? endpoints.endX : endpoints.endY
            return constrainBranchCoordinate(
                (branchCoordinateByParentAndDirection[directionKey]
                    ?? (startCoordinate + ((endCoordinate - startCoordinate) / 2))) + laneOffsets.start,
                start: startCoordinate,
                end: endCoordinate
            )
        }

        return outwardBranchCoordinate(
            for: template.startSide,
            geometry: RouteGeometry(
                axis: template.axis,
                startX: endpoints.startX,
                startY: endpoints.startY,
                branchCoordinate: 0,
                endX: endpoints.endX,
                endY: endpoints.endY
            ),
            offset: rerouteOutwardBranchOffsets[0] + laneOffsetForSameSideBranch(laneOffsets: laneOffsets)
        )
    }

    private static func laneOffsetForSameSideBranch(laneOffsets: EdgeLaneOffsets) -> Double {
        laneOffsets.start
    }

    private static func sameSideTemplateBiasPenalty(
        template: RouteTemplate,
        laneOffsets: EdgeLaneOffsets
    ) -> Double {
        let laneBias = laneOffsets.start + laneOffsets.end
        guard laneBias != 0 else {
            return 0
        }

        switch template.startSide {
        case .top:
            return laneBias < 0 ? 0 : 240
        case .bottom:
            return laneBias > 0 ? 0 : 240
        case .left:
            return laneBias < 0 ? 0 : 240
        case .right:
            return laneBias > 0 ? 0 : 240
        }
    }

    private static func outwardBranchCoordinate(
        for side: AnchorSide,
        geometry: RouteGeometry,
        offset: Double
    ) -> Double {
        switch side {
        case .left:
            return min(geometry.startX, geometry.endX) - offset
        case .right:
            return max(geometry.startX, geometry.endX) + offset
        case .top:
            return min(geometry.startY, geometry.endY) - offset
        case .bottom:
            return max(geometry.startY, geometry.endY) + offset
        }
    }

    private static func blockerHitCount(
        for route: PolylineRoute,
        blockers: [RoutingNodeBlocker]
    ) -> Int {
        blockers.reduce(into: 0) { count, blocker in
            if routeIntersectsBlocker(route: route, blocker: blocker) {
                count += 1
            }
        }
    }

    private static func routeIntersectsBlocker(
        route: PolylineRoute,
        blocker: RoutingNodeBlocker
    ) -> Bool {
        let points = route.points
        guard points.count >= 2 else {
            return false
        }
        for index in 0..<(points.count - 1)
        where segmentIntersectsRect(start: points[index], end: points[index + 1], rect: blocker.bounds) {
            return true
        }
        return false
    }

    private static func polylineLength(_ route: PolylineRoute) -> Double {
        let points = route.points
        guard points.count >= 2 else {
            return 0
        }
        return (1..<points.count).reduce(into: 0.0) { length, index in
            length += abs(Double(points[index].x - points[index - 1].x))
            length += abs(Double(points[index].y - points[index - 1].y))
        }
    }

    private static func isRouteCandidateBetter(_ lhs: RouteCandidate, _ rhs: RouteCandidate) -> Bool {
        if lhs.cost != rhs.cost {
            return lhs.cost < rhs.cost
        }
        if lhs.blockerHitCount != rhs.blockerHitCount {
            return lhs.blockerHitCount < rhs.blockerHitCount
        }
        return polylineSignature(lhs.route) < polylineSignature(rhs.route)
    }

    private static func polylineSignature(_ route: PolylineRoute) -> String {
        route.points.map { point in
            "\(point.x),\(point.y)"
        }
        .joined(separator: "|")
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

    private static func segmentIntersectsRect(
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
}
// swiftlint:enable file_length
