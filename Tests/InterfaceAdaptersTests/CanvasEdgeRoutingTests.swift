// Background: Edge readability regressed when many siblings were connected with straight lines.
// Responsibility: Verify branched edge routing keeps branch columns and side anchors consistent.
import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasEdgeRouting: duplicated edges receive symmetric lane offsets on both endpoints")
func test_laneOffsetsByEdgeID_forDuplicatedEdges_returnsSymmetricOffsets() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeAID = CanvasEdgeID(rawValue: "edge-a")
    let edgeBID = CanvasEdgeID(rawValue: "edge-b")
    let edges = [
        CanvasEdge(id: edgeAID, fromNodeID: parentID, toNodeID: childID, relationType: .normal),
        CanvasEdge(id: edgeBID, fromNodeID: parentID, toNodeID: childID, relationType: .normal),
    ]
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 80, y: 200, width: 220, height: 220),
        childID: makeNode(id: childID, x: 460, y: 360, width: 220, height: 220),
    ]

    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(edges: edges, nodesByID: nodesByID)

    let laneOffsetsA = try #require(laneOffsetsByEdgeID[edgeAID])
    let laneOffsetsB = try #require(laneOffsetsByEdgeID[edgeBID])
    #expect(laneOffsetsA.start == -laneOffsetsB.start)
    #expect(laneOffsetsA.end == -laneOffsetsB.end)
    #expect(laneOffsetsA.start < 0)
    #expect(laneOffsetsB.start > 0)
}

@Test("CanvasEdgeRouting: opposite directions between same nodes also receive split lanes")
func test_laneOffsetsByEdgeID_forOppositeDirections_returnsSymmetricOffsets() throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let edgeBAID = CanvasEdgeID(rawValue: "edge-b-a")
    let edges = [
        CanvasEdge(id: edgeABID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
        CanvasEdge(id: edgeBAID, fromNodeID: nodeBID, toNodeID: nodeAID, relationType: .normal),
    ]
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        nodeAID: makeNode(id: nodeAID, x: 80, y: 200, width: 220, height: 220),
        nodeBID: makeNode(id: nodeBID, x: 460, y: 360, width: 220, height: 220),
    ]

    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(edges: edges, nodesByID: nodesByID)
    let laneOffsetsAB = try #require(laneOffsetsByEdgeID[edgeABID])
    let laneOffsetsBA = try #require(laneOffsetsByEdgeID[edgeBAID])
    #expect(laneOffsetsAB.start == -laneOffsetsBA.end)
    #expect(laneOffsetsAB.end == -laneOffsetsBA.start)
    #expect(laneOffsetsAB.start != 0)
    #expect(laneOffsetsBA.start != 0)
}

@Test("CanvasEdgeRouting: sibling edges share a branch column between parent and children on right side")
func test_branchCoordinateByParentAndDirection_rightSideChildren_placesBranchBetweenNodes() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childTopID = CanvasNodeID(rawValue: "child-top")
    let childBottomID = CanvasNodeID(rawValue: "child-bottom")
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 40, y: 200, width: 220, height: 56),
        childTopID: makeNode(id: childTopID, x: 420, y: 120, width: 220, height: 56),
        childBottomID: makeNode(id: childBottomID, x: 420, y: 300, width: 220, height: 56),
    ]
    let edges = [
        CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childTopID),
        CanvasEdge(id: CanvasEdgeID(rawValue: "edge-2"), fromNodeID: parentID, toNodeID: childBottomID),
    ]

    let branchCoordinateByParentAndDirection = CanvasEdgeRouting.branchCoordinateByParentAndDirection(
        edges: edges,
        nodesByID: nodesByID
    )
    let key = CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .horizontal, direction: 1)
    let branchCoordinate = branchCoordinateByParentAndDirection[key]

    #expect(branchCoordinate != nil)
    if let branchCoordinate {
        #expect(branchCoordinate > 260)  // parent right edge
        #expect(branchCoordinate < 420)  // child left edge
    }
}

@Test("CanvasEdgeRouting: single right-side child places branch at midpoint between node sides")
func test_branchCoordinateByParentAndDirection_singleRightChild_placesBranchAtMidpoint() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 40, y: 200, width: 220, height: 56),
        childID: makeNode(id: childID, x: 420, y: 240, width: 220, height: 56),
    ]
    let edges = [
        CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    ]

    let branchCoordinateByParentAndDirection = CanvasEdgeRouting.branchCoordinateByParentAndDirection(
        edges: edges,
        nodesByID: nodesByID
    )
    let key = CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .horizontal, direction: 1)
    let branchCoordinate = try #require(branchCoordinateByParentAndDirection[key])

    // Midpoint between parent right edge (260) and child left edge (420).
    #expect(branchCoordinate == 340)
}

@Test("CanvasEdgeRouting: mixed left and right children keep separate branch columns")
func test_branchCoordinateByParentAndDirection_mixedSideChildren_buildsBothBranchColumns() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let rightChildID = CanvasNodeID(rawValue: "right-child")
    let leftChildID = CanvasNodeID(rawValue: "left-child")
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 300, y: 220, width: 220, height: 56),
        rightChildID: makeNode(id: rightChildID, x: 700, y: 160, width: 200, height: 56),
        leftChildID: makeNode(id: leftChildID, x: 40, y: 320, width: 200, height: 56),
    ]
    let edges = [
        CanvasEdge(id: CanvasEdgeID(rawValue: "edge-right"), fromNodeID: parentID, toNodeID: rightChildID),
        CanvasEdge(id: CanvasEdgeID(rawValue: "edge-left"), fromNodeID: parentID, toNodeID: leftChildID),
    ]

    let branchCoordinateByParentAndDirection = CanvasEdgeRouting.branchCoordinateByParentAndDirection(
        edges: edges,
        nodesByID: nodesByID
    )
    let rightKey = CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .horizontal, direction: 1)
    let leftKey = CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .horizontal, direction: -1)
    let rightBranchCoordinate = branchCoordinateByParentAndDirection[rightKey]
    let leftBranchCoordinate = branchCoordinateByParentAndDirection[leftKey]

    #expect(rightBranchCoordinate != nil)
    #expect(leftBranchCoordinate != nil)
    if let rightBranchCoordinate {
        #expect(rightBranchCoordinate > 520)  // parent right edge
        #expect(rightBranchCoordinate < 700)  // right child left edge
    }
    if let leftBranchCoordinate {
        #expect(leftBranchCoordinate < 300)  // parent left edge
        #expect(leftBranchCoordinate > 240)  // left child right edge
    }
}

@Test("CanvasEdgeRouting: route geometry fallback uses midpoint when shared branch is absent")
func test_routeGeometry_withoutSharedBranch_usesMidpointFallback() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        childID: makeNode(id: childID, x: 460, y: 360, width: 220, height: 56),
    ]

    let geometry = CanvasEdgeRouting.routeGeometry(
        for: edge,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: [:]
    )

    #expect(geometry != nil)
    #expect(geometry?.axis == .horizontal)
    // Midpoint between parent right edge (300) and child left edge (460).
    #expect(geometry?.branchCoordinate == 380)
}

@Test("CanvasEdgeRouting: route geometry uses side anchors and shared branch column")
func test_routeGeometry_usesNodeSidesAndParentBranchX() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        childID: makeNode(id: childID, x: 460, y: 360, width: 220, height: 56),
    ]
    let branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double] = [
        CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .horizontal, direction: 1): 350
    ]

    let geometry = CanvasEdgeRouting.routeGeometry(
        for: edge,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
    )

    #expect(geometry != nil)
    #expect(geometry?.axis == .horizontal)
    #expect(geometry?.startX == 300)  // parent right edge
    #expect(geometry?.endX == 460)  // child left edge
    #expect(geometry?.branchCoordinate == 350)
    #expect(geometry?.startY == 228)
    #expect(geometry?.endY == 388)
}

@Test("CanvasEdgeRouting: duplicated horizontal edges use distinct start and end anchors")
func test_routeGeometry_withLaneOffsets_separatesDuplicatedHorizontalEdges() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeAID = CanvasEdgeID(rawValue: "edge-a")
    let edgeBID = CanvasEdgeID(rawValue: "edge-b")
    let edgeA = CanvasEdge(id: edgeAID, fromNodeID: parentID, toNodeID: childID, relationType: .normal)
    let edgeB = CanvasEdge(id: edgeBID, fromNodeID: parentID, toNodeID: childID, relationType: .normal)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 80, y: 200, width: 220, height: 220),
        childID: makeNode(id: childID, x: 460, y: 360, width: 220, height: 220),
    ]
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: [edgeA, edgeB],
        nodesByID: nodesByID
    )

    let geometryA = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edgeA,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID
        )
    )
    let geometryB = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edgeB,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID
        )
    )

    #expect(geometryA.axis == .horizontal)
    #expect(geometryB.axis == .horizontal)
    #expect(geometryA.startX == geometryB.startX)
    #expect(geometryA.endX == geometryB.endX)
    #expect(geometryA.startY != geometryB.startY)
    #expect(geometryA.endY != geometryB.endY)
    #expect(geometryA.branchCoordinate != geometryB.branchCoordinate)
}

@Test("CanvasEdgeRouting: edges sharing only one node side still receive separated anchors")
func test_routeGeometry_withSharedOneSideNode_separatesSharedAnchors() throws {
    let sharedNodeID = CanvasNodeID(rawValue: "shared")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let edgeACID = CanvasEdgeID(rawValue: "edge-a-c")
    let edgeAB = CanvasEdge(id: edgeABID, fromNodeID: sharedNodeID, toNodeID: nodeBID, relationType: .normal)
    let edgeAC = CanvasEdge(id: edgeACID, fromNodeID: sharedNodeID, toNodeID: nodeCID, relationType: .normal)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        sharedNodeID: makeNode(id: sharedNodeID, x: 80, y: 200, width: 220, height: 220),
        nodeBID: makeNode(id: nodeBID, x: 460, y: 120, width: 220, height: 220),
        nodeCID: makeNode(id: nodeCID, x: 460, y: 420, width: 220, height: 220),
    ]
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: [edgeAB, edgeAC],
        nodesByID: nodesByID
    )

    let geometryAB = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edgeAB,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID
        )
    )
    let geometryAC = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edgeAC,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID
        )
    )

    #expect(geometryAB.axis == .horizontal)
    #expect(geometryAC.axis == .horizontal)
    #expect(geometryAB.startX == geometryAC.startX)
    #expect(geometryAB.startY != geometryAC.startY)
}

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
        parentID: makeNode(id: parentID, x: 80, y: 220, width: 220, height: 220),
        upperChildID: makeNode(id: upperChildID, x: 460, y: 120, width: 220, height: 220),
        lowerChildID: makeNode(id: lowerChildID, x: 460, y: 420, width: 220, height: 220),
    ]
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: [upperEdge, lowerEdge],
        nodesByID: nodesByID
    )

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
        upperParentID: makeNode(id: upperParentID, x: 80, y: 120, width: 220, height: 220),
        lowerParentID: makeNode(id: lowerParentID, x: 80, y: 420, width: 220, height: 220),
        childID: makeNode(id: childID, x: 460, y: 220, width: 220, height: 220),
    ]
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: [upperEdge, lowerEdge],
        nodesByID: nodesByID
    )

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

@Test("CanvasEdgeRouting: left-side child route enters from child right edge")
func test_routeGeometry_leftDirection_usesOppositeSides() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 440, y: 200, width: 220, height: 56),
        childID: makeNode(id: childID, x: 120, y: 320, width: 220, height: 56),
    ]
    let branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double] = [
        CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .horizontal, direction: -1): 380
    ]

    let geometry = CanvasEdgeRouting.routeGeometry(
        for: edge,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
    )

    #expect(geometry != nil)
    #expect(geometry?.axis == .horizontal)
    #expect(geometry?.startX == 440)  // parent left edge
    #expect(geometry?.endX == 340)  // child right edge
    #expect(geometry?.branchCoordinate == 380)
}

@Test("CanvasEdgeRouting: overlapping nodes determine direction from centers")
func test_routeGeometry_overlappingNodes_usesCenterBasedDirection() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 200, y: 200, width: 200, height: 56),
        childID: makeNode(id: childID, x: 250, y: 220, width: 20, height: 56),
    ]
    let branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double] = [
        CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .horizontal, direction: -1): 230
    ]

    let geometry = CanvasEdgeRouting.routeGeometry(
        for: edge,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
    )

    #expect(geometry != nil)
    #expect(geometry?.startX == 200)  // parent left edge
    #expect(geometry?.endX == 270)  // child right edge
}

@Test("CanvasEdgeRouting: vertically aligned nodes connect from bottom to top centers")
func test_routeGeometry_verticalAlignment_usesTopBottomAnchors() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 240, y: 120, width: 220, height: 56),
        childID: makeNode(id: childID, x: 280, y: 420, width: 220, height: 56),
    ]
    let branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double] = [
        CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .vertical, direction: 1): 320
    ]

    let geometry = CanvasEdgeRouting.routeGeometry(
        for: edge,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
    )

    #expect(geometry != nil)
    #expect(geometry?.axis == .vertical)
    #expect(geometry?.startX == 350)  // parent centerX
    #expect(geometry?.startY == 176)  // parent bottom edge
    #expect(geometry?.endX == 390)  // child centerX
    #expect(geometry?.endY == 420)  // child top edge
    #expect(geometry?.branchCoordinate == 320)
}

@Test("CanvasEdgeRouting: relatively vertical relation prefers vertical routing")
func test_routeGeometry_relativelyVertical_prefersVerticalRouting() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 100, y: 100, width: 220, height: 56),
        childID: makeNode(id: childID, x: 280, y: 310, width: 220, height: 56),
    ]

    let geometry = CanvasEdgeRouting.routeGeometry(
        for: edge,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: [:]
    )

    #expect(geometry?.axis == .vertical)
    #expect(geometry?.startY == 156)  // parent bottom edge
    #expect(geometry?.endY == 310)  // child top edge
}

private func makeNode(
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
