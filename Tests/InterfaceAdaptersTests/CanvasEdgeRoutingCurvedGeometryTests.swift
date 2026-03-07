import Domain
import Testing

@testable import InterfaceAdapters

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
        routeGeometry: downward, laneOffsets: .init(start: 10, end: 10))
    let upwardCurve = CanvasEdgeRouting.curvedGeometry(routeGeometry: upward, laneOffsets: .init(start: 10, end: 10))

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

    let nearCurve = CanvasEdgeRouting.curvedGeometry(routeGeometry: geometry, laneOffsets: .init(start: 7, end: 7))
    let farCurve = CanvasEdgeRouting.curvedGeometry(routeGeometry: geometry, laneOffsets: .init(start: 21, end: 21))

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

    let splitCurve = CanvasEdgeRouting.curvedGeometry(routeGeometry: geometry, laneOffsets: .init(start: -21, end: 21))

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
