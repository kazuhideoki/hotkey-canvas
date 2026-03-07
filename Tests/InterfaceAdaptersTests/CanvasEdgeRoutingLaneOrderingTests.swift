import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasEdgeRouting: sibling edges on one side follow counterpart order to avoid immediate crossing")
func test_routeGeometry_withSharedStartSide_ordersLanesByCounterpartPosition() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let upperChildID = CanvasNodeID(rawValue: "upper-child")
    let lowerChildID = CanvasNodeID(rawValue: "lower-child")
    let laterEdgeID = CanvasEdgeID(rawValue: "edge-z")
    let earlierEdgeID = CanvasEdgeID(rawValue: "edge-a")
    let upperEdge = CanvasEdge(id: laterEdgeID, fromNodeID: parentID, toNodeID: upperChildID, relationType: .normal)
    let lowerEdge = CanvasEdge(id: earlierEdgeID, fromNodeID: parentID, toNodeID: lowerChildID, relationType: .normal)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeLaneOrderingNode(id: parentID, x: 80, y: 220, width: 220, height: 220),
        upperChildID: makeLaneOrderingNode(id: upperChildID, x: 460, y: 120, width: 220, height: 220),
        lowerChildID: makeLaneOrderingNode(id: lowerChildID, x: 460, y: 420, width: 220, height: 220),
    ]
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: [upperEdge, lowerEdge], nodesByID: nodesByID)

    let upperGeometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: upperEdge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID
        )
    )
    let lowerGeometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: lowerEdge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID
        )
    )

    #expect(upperGeometry.axis == .horizontal)
    #expect(lowerGeometry.axis == .horizontal)
    #expect(upperGeometry.startX == lowerGeometry.startX)
    #expect(upperGeometry.startY < lowerGeometry.startY)
    #expect(upperGeometry.endY < lowerGeometry.endY)
}

@Test("CanvasEdgeRouting: sibling edges on one end side follow counterpart order to avoid immediate crossing")
func test_routeGeometry_withSharedEndSide_ordersLanesByCounterpartPosition() throws {
    let upperParentID = CanvasNodeID(rawValue: "upper-parent")
    let lowerParentID = CanvasNodeID(rawValue: "lower-parent")
    let childID = CanvasNodeID(rawValue: "child")
    let laterEdgeID = CanvasEdgeID(rawValue: "edge-z")
    let earlierEdgeID = CanvasEdgeID(rawValue: "edge-a")
    let upperEdge = CanvasEdge(id: laterEdgeID, fromNodeID: upperParentID, toNodeID: childID, relationType: .normal)
    let lowerEdge = CanvasEdge(id: earlierEdgeID, fromNodeID: lowerParentID, toNodeID: childID, relationType: .normal)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        upperParentID: makeLaneOrderingNode(id: upperParentID, x: 80, y: 120, width: 220, height: 220),
        lowerParentID: makeLaneOrderingNode(id: lowerParentID, x: 80, y: 420, width: 220, height: 220),
        childID: makeLaneOrderingNode(id: childID, x: 460, y: 220, width: 220, height: 220),
    ]
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: [upperEdge, lowerEdge], nodesByID: nodesByID)

    let upperGeometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: upperEdge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID
        )
    )
    let lowerGeometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: lowerEdge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID
        )
    )

    #expect(upperGeometry.axis == .horizontal)
    #expect(lowerGeometry.axis == .horizontal)
    #expect(upperGeometry.endX == lowerGeometry.endX)
    #expect(upperGeometry.endY < lowerGeometry.endY)
    #expect(upperGeometry.startY < lowerGeometry.startY)
}

private func makeLaneOrderingNode(
    id: CanvasNodeID,
    x: Double,
    y: Double,
    width: Double,
    height: Double
) -> CanvasNode {
    CanvasNode(
        id: id,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: x, y: y, width: width, height: height)
    )
}
