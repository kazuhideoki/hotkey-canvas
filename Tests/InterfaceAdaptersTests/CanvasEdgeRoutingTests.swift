// Background: Edge readability regressed when many siblings were connected with straight lines.
// Responsibility: Verify branched edge routing keeps branch columns and side anchors consistent.
import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasEdgeRouting: sibling edges share a branch column between parent and children on right side")
func test_branchXByParent_rightSideChildren_placesBranchBetweenNodes() {
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

    let branchXByParentAndDirection = CanvasEdgeRouting.branchXByParentAndDirection(
        edges: edges,
        nodesByID: nodesByID
    )
    let key = CanvasEdgeRouting.BranchKey(parentNodeID: parentID, direction: 1)
    let branchX = branchXByParentAndDirection[key]

    #expect(branchX != nil)
    if let branchX {
        #expect(branchX > 260)  // parent right edge
        #expect(branchX < 420)  // child left edge
    }
}

@Test("CanvasEdgeRouting: mixed left and right children keep separate branch columns")
func test_branchXByParentAndDirection_mixedSideChildren_buildsBothBranchColumns() {
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

    let branchXByParentAndDirection = CanvasEdgeRouting.branchXByParentAndDirection(
        edges: edges,
        nodesByID: nodesByID
    )
    let rightKey = CanvasEdgeRouting.BranchKey(parentNodeID: parentID, direction: 1)
    let leftKey = CanvasEdgeRouting.BranchKey(parentNodeID: parentID, direction: -1)
    let rightBranchX = branchXByParentAndDirection[rightKey]
    let leftBranchX = branchXByParentAndDirection[leftKey]

    #expect(rightBranchX != nil)
    #expect(leftBranchX != nil)
    if let rightBranchX {
        #expect(rightBranchX > 520)  // parent right edge
        #expect(rightBranchX < 700)  // right child left edge
    }
    if let leftBranchX {
        #expect(leftBranchX < 300)  // parent left edge
        #expect(leftBranchX > 240)  // left child right edge
    }
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
    let branchXByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double] = [
        CanvasEdgeRouting.BranchKey(parentNodeID: parentID, direction: 1): 350
    ]

    let geometry = CanvasEdgeRouting.routeGeometry(
        for: edge,
        nodesByID: nodesByID,
        branchXByParentAndDirection: branchXByParentAndDirection
    )

    #expect(geometry != nil)
    #expect(geometry?.startX == 300)  // parent right edge
    #expect(geometry?.endX == 460)  // child left edge
    #expect(geometry?.branchX == 350)
    #expect(geometry?.startY == 228)
    #expect(geometry?.endY == 388)
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
    let branchXByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double] = [
        CanvasEdgeRouting.BranchKey(parentNodeID: parentID, direction: -1): 380
    ]

    let geometry = CanvasEdgeRouting.routeGeometry(
        for: edge,
        nodesByID: nodesByID,
        branchXByParentAndDirection: branchXByParentAndDirection
    )

    #expect(geometry != nil)
    #expect(geometry?.startX == 440)  // parent left edge
    #expect(geometry?.endX == 340)  // child right edge
    #expect(geometry?.branchX == 380)
}

@Test("CanvasEdgeRouting: overlapping nodes determine direction from centers")
func test_routeGeometry_overlappingNodes_usesCenterBasedDirection() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 200, y: 200, width: 200, height: 56),
        childID: makeNode(id: childID, x: 250, y: 320, width: 20, height: 56),
    ]
    let branchXByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double] = [
        CanvasEdgeRouting.BranchKey(parentNodeID: parentID, direction: -1): 230
    ]

    let geometry = CanvasEdgeRouting.routeGeometry(
        for: edge,
        nodesByID: nodesByID,
        branchXByParentAndDirection: branchXByParentAndDirection
    )

    #expect(geometry != nil)
    #expect(geometry?.startX == 200)  // parent left edge
    #expect(geometry?.endX == 270)  // child right edge
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
