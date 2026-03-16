import CoreGraphics
import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasEdgeRouting: curved resolved geometry keeps the base curve when no blocker exists")
func test_resolvedCurvedGeometry_withoutBlocker_matchesBaseCurve() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeCurvedGeometryNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeCurvedGeometryNode(id: childID, x: 460, y: 360, width: 220, height: 56),
    ])
    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )

    let baseCurve = CanvasEdgeRouting.curvedGeometry(routeGeometry: geometry, laneOffsets: .zero)
    let resolvedCurve = CanvasEdgeRouting.resolvedCurvedGeometry(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID,
        laneOffsets: .zero
    )

    #expect(resolvedCurve.control1 == baseCurve.control1)
    #expect(resolvedCurve.control2 == baseCurve.control2)
}

@Test("CanvasEdgeRouting: curved resolved geometry bends away from a middle blocker")
func test_resolvedCurvedGeometry_withMiddleBlocker_avoidsNonEndpointNode() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeCurvedGeometryNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeCurvedGeometryNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeCurvedGeometryNode(id: blockerID, x: 344, y: 252, width: 72, height: 72),
    ])
    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let blockerNode = try #require(nodesByID[blockerID])

    let baseCurve = CanvasEdgeRouting.curvedGeometry(routeGeometry: geometry, laneOffsets: .zero)
    let resolvedCurve = CanvasEdgeRouting.resolvedCurvedGeometry(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID,
        laneOffsets: .zero
    )

    #expect(curvedRouteIntersectsNode(baseCurve, geometry: geometry, node: blockerNode, padding: 18))
    #expect(!curvedRouteIntersectsNode(resolvedCurve, geometry: geometry, node: blockerNode, padding: 18))
}

@Test("CanvasEdgeRouting: curved label anchor follows the avoided curve instead of the blocked midpoint")
func test_labelAnchor_curvedAvoidedEdge_staysOffBlockedMidpoint() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeCurvedGeometryNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeCurvedGeometryNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeCurvedGeometryNode(id: blockerID, x: 344, y: 252, width: 72, height: 72),
    ])
    let blockerNode = try #require(nodesByID[blockerID])

    let anchor = try #require(
        CanvasEdgeRouting.labelAnchor(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            edgeShapeStyle: .curved
        )
    )

    #expect(!paddedRect(for: blockerNode, padding: 18).contains(anchor.point))
    #expect(abs(anchor.point.x - 380) > 1 || abs(anchor.point.y - 308) > 1)
}

@Test("CanvasEdgeRouting: curved avoided edge tip follows the avoided terminal tangent")
func test_edgeTipAndVector_curvedAvoidedEdge_tracksResolvedCurveTerminalTangent() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-1"),
        fromNodeID: parentID,
        toNodeID: childID,
        relationType: .normal,
        directionality: .fromTo
    )
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeCurvedGeometryNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeCurvedGeometryNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeCurvedGeometryNode(id: blockerID, x: 344, y: 252, width: 72, height: 72),
    ])
    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let resolvedCurve = CanvasEdgeRouting.resolvedCurvedGeometry(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID,
        laneOffsets: .zero
    )
    let tipAndVector = try #require(
        CanvasEdgeRouting.edgeTipAndVector(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            edgeShapeStyle: .curved
        )
    )
    let expectedTip = CGPoint(x: geometry.endX, y: geometry.endY)
    let expectedVector = CGVector(
        dx: expectedTip.x - resolvedCurve.control2.x,
        dy: expectedTip.y - resolvedCurve.control2.y
    )
    let normalizedTipVector = try #require(normalized(tipAndVector.vector))
    let normalizedExpectedVector = try #require(normalized(expectedVector))

    #expect(tipAndVector.tip == expectedTip)
    #expect(normalizedTipVector == normalizedExpectedVector)
}

@Test("CanvasEdgeRouting: curved geometry bulges outward for vertical routes regardless of edge direction")
func test_curvedGeometry_verticalRoute_positiveLaneBulgesOutwardForBothDirections() {
    let downward = CanvasEdgeRouting.RouteGeometry(
        axis: .vertical,
        startX: 300,
        startY: 120,
        branchCoordinate: 300,
        endX: 300,
        endY: 520
    )
    let upward = CanvasEdgeRouting.RouteGeometry(
        axis: .vertical,
        startX: 300,
        startY: 520,
        branchCoordinate: 300,
        endX: 300,
        endY: 120
    )

    let downwardCurve = CanvasEdgeRouting.curvedGeometry(
        routeGeometry: downward,
        laneOffsets: .init(start: 10, end: 10)
    )
    let upwardCurve = CanvasEdgeRouting.curvedGeometry(
        routeGeometry: upward,
        laneOffsets: .init(start: 10, end: 10)
    )

    #expect(downwardCurve.control1.x > downward.startX)
    #expect(downwardCurve.control2.x > downward.endX)
    #expect(upwardCurve.control1.x > upward.startX)
    #expect(upwardCurve.control2.x > upward.endX)
}

@Test("CanvasEdgeRouting: curved geometry increases bulge as lane gets farther from center")
func test_curvedGeometry_largerLaneOffsetIncreasesBulge() {
    let geometry = CanvasEdgeRouting.RouteGeometry(
        axis: .horizontal,
        startX: 120,
        startY: 220,
        branchCoordinate: 320,
        endX: 620,
        endY: 220
    )

    let nearCurve = CanvasEdgeRouting.curvedGeometry(
        routeGeometry: geometry,
        laneOffsets: .init(start: 7, end: 7)
    )
    let farCurve = CanvasEdgeRouting.curvedGeometry(
        routeGeometry: geometry,
        laneOffsets: .init(start: 21, end: 21)
    )

    #expect(farCurve.control1.y - geometry.startY > nearCurve.control1.y - geometry.startY)
    #expect(farCurve.control2.y - geometry.endY > nearCurve.control2.y - geometry.endY)
}

@Test("CanvasEdgeRouting: curved geometry respects different lane offsets at start and end")
func test_curvedGeometry_withDistinctStartAndEndLanes_followsEachEndpointLane() {
    let geometry = CanvasEdgeRouting.RouteGeometry(
        axis: .horizontal,
        startX: 120,
        startY: 220,
        branchCoordinate: 320,
        endX: 620,
        endY: 220
    )

    let splitCurve = CanvasEdgeRouting.curvedGeometry(
        routeGeometry: geometry,
        laneOffsets: .init(start: -21, end: 21)
    )

    #expect(splitCurve.control1.y < geometry.startY)
    #expect(splitCurve.control2.y > geometry.endY)
}

@Test("CanvasEdgeRouting: edge tip vector respects asymmetric lanes on vertical curved routes")
func test_edgeTipAndVector_verticalCurvedRoute_withDistinctLanes_tracksEndLaneDirection() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeID = CanvasEdgeID(rawValue: "edge-1")
    let edge = CanvasEdge(
        id: edgeID,
        fromNodeID: parentID,
        toNodeID: childID,
        relationType: .normal,
        directionality: .fromTo
    )
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeCurvedGeometryNode(id: parentID, x: 240, y: 120, width: 220, height: 56),
        makeCurvedGeometryNode(id: childID, x: 280, y: 420, width: 220, height: 56),
    ])
    let branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double] = [
        CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .vertical, direction: 1): 320
    ]
    let laneOffsetsByEdgeID: [CanvasEdgeID: CanvasEdgeRouting.EdgeLaneOffsets] = [edgeID: .init(start: -21, end: 21)]

    let tipAndVector = try #require(
        CanvasEdgeRouting.edgeTipAndVector(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
            laneOffsetsByEdgeID: laneOffsetsByEdgeID,
            edgeShapeStyle: .curved
        )
    )

    #expect(tipAndVector.tip.y == 420)
    #expect(tipAndVector.vector.dx < 0)
    #expect(tipAndVector.vector.dy > 0)
}

@Test("CanvasEdgeRouting: curved route avoids a terminal blocker by rerouting to another side")
func test_resolvedCurvedGeometry_withTerminalBlocker_avoidsByChangingAnchors() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeCurvedGeometryNode(id: parentID, x: 40, y: 180, width: 220, height: 220),
        makeCurvedGeometryNode(id: childID, x: 760, y: 180, width: 220, height: 220),
        makeCurvedGeometryNode(id: blockerID, x: 300, y: 140, width: 220, height: 220),
    ])
    let blockerNode = try #require(nodesByID[blockerID])
    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let curve = CanvasEdgeRouting.resolvedCurvedGeometry(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID,
        laneOffsets: .zero
    )

    #expect(!curvedRouteIntersectsNode(curve, geometry: geometry, node: blockerNode, padding: 18))
}

@Test("CanvasEdgeRouting: curved node avoidance can be disabled and keeps the base curve")
func test_resolvedCurvedGeometry_whenNodeAvoidanceDisabled_keepsBaseCurve() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeCurvedGeometryNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeCurvedGeometryNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeCurvedGeometryNode(id: blockerID, x: 344, y: 252, width: 72, height: 72),
    ])
    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )

    let baseCurve = CanvasEdgeRouting.curvedGeometry(routeGeometry: geometry, laneOffsets: .zero)
    let curveWithoutAvoidance = CanvasEdgeRouting.resolvedCurvedGeometry(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID,
        laneOffsets: .zero,
        nodeAvoidanceEnabled: false
    )

    #expect(curveWithoutAvoidance.control1 == baseCurve.control1)
    #expect(curveWithoutAvoidance.control2 == baseCurve.control2)
    #expect(
        curvedRouteIntersectsNode(
            curveWithoutAvoidance, geometry: geometry, node: try #require(nodesByID[blockerID]), padding: 18))
}

private func makeCurvedGeometryNode(
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

private func curvedRouteIntersectsNode(
    _ curve: CanvasEdgeRouting.CurveGeometry,
    geometry: CanvasEdgeRouting.RouteGeometry,
    node: CanvasNode,
    padding: Double
) -> Bool {
    let rect = paddedRect(for: node, padding: padding)
    let start = CGPoint(x: geometry.startX, y: geometry.startY)
    let end = CGPoint(x: geometry.endX, y: geometry.endY)
    let points = (0...32).map { index in
        let parameter = CGFloat(index) / 32
        return CanvasEdgeRouting.cubicBezierPoint(
            start: start,
            control1: curve.control1,
            control2: curve.control2,
            end: end,
            parameter: parameter
        )
    }

    for point in points where rect.contains(point) {
        return true
    }
    for index in 0..<(points.count - 1)
    where segmentIntersectsRect(start: points[index], end: points[index + 1], rect: rect) {
        return true
    }
    return false
}

private func paddedRect(for node: CanvasNode, padding: Double) -> CGRect {
    CGRect(
        x: node.bounds.x - padding,
        y: node.bounds.y - padding,
        width: node.bounds.width + (padding * 2),
        height: node.bounds.height + (padding * 2)
    )
}

private func segmentIntersectsRect(
    start: CGPoint,
    end: CGPoint,
    rect: CGRect
) -> Bool {
    guard
        rect.intersects(
            CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ).insetBy(dx: -0.0001, dy: -0.0001))
    else {
        return false
    }
    if rect.contains(start) || rect.contains(end) {
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

private func segmentsIntersect(
    _ pointA: CGPoint,
    _ pointB: CGPoint,
    _ pointC: CGPoint,
    _ pointD: CGPoint
) -> Bool {
    let cross1 = cross(pointA, pointB, pointC)
    let cross2 = cross(pointA, pointB, pointD)
    let cross3 = cross(pointC, pointD, pointA)
    let cross4 = cross(pointC, pointD, pointB)

    if abs(cross1) < 0.0001, onSegment(pointC, pointA, pointB) {
        return true
    }
    if abs(cross2) < 0.0001, onSegment(pointD, pointA, pointB) {
        return true
    }
    if abs(cross3) < 0.0001, onSegment(pointA, pointC, pointD) {
        return true
    }
    if abs(cross4) < 0.0001, onSegment(pointB, pointC, pointD) {
        return true
    }

    return ((cross1 > 0) != (cross2 > 0)) && ((cross3 > 0) != (cross4 > 0))
}

private func cross(_ origin: CGPoint, _ target: CGPoint, _ point: CGPoint) -> CGFloat {
    let dx1 = target.x - origin.x
    let dy1 = target.y - origin.y
    let dx2 = point.x - origin.x
    let dy2 = point.y - origin.y
    return (dx1 * dy2) - (dy1 * dx2)
}

private func onSegment(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> Bool {
    point.x >= min(start.x, end.x) - 0.0001
        && point.x <= max(start.x, end.x) + 0.0001
        && point.y >= min(start.y, end.y) - 0.0001
        && point.y <= max(start.y, end.y) + 0.0001
}

private func normalized(_ vector: CGVector) -> CGVector? {
    let length = sqrt((vector.dx * vector.dx) + (vector.dy * vector.dy))
    guard length > 0.0001 else {
        return nil
    }
    return CGVector(dx: vector.dx / length, dy: vector.dy / length)
}
