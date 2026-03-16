// Background: Edge readability regressed when many siblings were connected with straight lines.
// Responsibility: Verify branched edge routing keeps branch columns and side anchors consistent.
import CoreGraphics
import Domain
import Testing

@testable import InterfaceAdapters

@Test("重複したエッジは両方の端点で対称レーンオフセットを受け取る")
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

@Test("同じノード間の反対方向でもスプリット レーンを受信する")
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

@Test("兄弟ノードのエッジは、右側の親と子の間で分岐列を共有する")
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

@Test("単一の右側の子ノードは、ノードの側面間の中間点に枝を配置する")
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

@Test("左右の混合子は別々の分岐列を保持する")
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

@Test("共有ブランチが存在しない場合、ルート ジオメトリ フォールバックは中間点を使う")
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

@Test("ルート ジオメトリはサイド アンカーと共有分岐列を使う")
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

@Test("重複した水平エッジは別個の開始アンカーと終了アンカーを使う")
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

@Test("1 つのノード側のみを共有するエッジは依然として分離されたアンカーを受け取る")
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

@Test("左側の子ノードのルートは子ノードの右端から入ります")
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

@Test("重なり合うノードは中心からの方向を決定する")
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

@Test("垂直に整列したノードが下から上の中心に接続する")
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

@Test("比較的垂直な関係は垂直ル​​ーティングを好みます")
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

@Test("ツリーの単純なルーティングは、比較的垂直な関係のために水平な分岐を維持する")
func test_routeGeometry_treeSimpleRelativeVertical_keepsHorizontalBranching() {
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
        branchCoordinateByParentAndDirection: [:],
        routingStyle: .treeSimple
    )

    #expect(geometry?.axis == .horizontal)
    #expect(geometry?.startX == 320)
    #expect(geometry?.endX == 280)
    #expect(geometry?.startY == 128)
    #expect(geometry?.endY == 338)
}

@Test("ツリーの単純な分岐座標は、垂直に分離された子に対して 1 つの水平分岐を共有する")
func test_treeBranchCoordinateByParentAndDirection_forVerticallySeparatedChildren_buildsSharedHorizontalBranch() {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childTopID = CanvasNodeID(rawValue: "child-top")
    let childBottomID = CanvasNodeID(rawValue: "child-bottom")
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        childTopID: makeNode(id: childTopID, x: 460, y: 120, width: 220, height: 56),
        childBottomID: makeNode(id: childBottomID, x: 460, y: 420, width: 220, height: 56),
    ]
    let edges = [
        CanvasEdge(id: CanvasEdgeID(rawValue: "edge-top"), fromNodeID: parentID, toNodeID: childTopID),
        CanvasEdge(id: CanvasEdgeID(rawValue: "edge-bottom"), fromNodeID: parentID, toNodeID: childBottomID),
    ]

    let branchCoordinates = CanvasEdgeRouting.treeBranchCoordinateByParentAndDirection(
        edges: edges,
        nodesByID: nodesByID
    )

    let key = CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .horizontal, direction: 1)
    let branchCoordinate = branchCoordinates[key]

    #expect(branchCoordinate != nil)
    if let branchCoordinate {
        #expect(branchCoordinate > 300)
        #expect(branchCoordinate < 460)
    }
}

@Test("ツリーの単純なルーティングは重複したエッジのレーンオフセットを無視する")
func test_routeGeometry_treeSimpleIgnoresLaneOffsets() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childTopID = CanvasNodeID(rawValue: "child-top")
    let childBottomID = CanvasNodeID(rawValue: "child-bottom")
    let edgeTop = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-top"),
        fromNodeID: parentID,
        toNodeID: childTopID,
        relationType: .normal
    )
    let edgeBottom = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-bottom"),
        fromNodeID: parentID,
        toNodeID: childBottomID,
        relationType: .normal
    )
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 80, y: 200, width: 220, height: 220),
        childTopID: makeNode(id: childTopID, x: 460, y: 120, width: 220, height: 220),
        childBottomID: makeNode(id: childBottomID, x: 460, y: 420, width: 220, height: 220),
    ]
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: [edgeTop, edgeBottom],
        nodesByID: nodesByID
    )

    let geometryTop = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edgeTop,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID,
            routingStyle: .treeSimple
        )
    )
    let geometryBottom = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edgeBottom,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID,
            routingStyle: .treeSimple
        )
    )

    #expect(geometryTop.axis == .horizontal)
    #expect(geometryBottom.axis == .horizontal)
    #expect(geometryTop.startX == geometryBottom.startX)
    #expect(geometryTop.endX == geometryBottom.endX)
    #expect(geometryTop.startY == 310)
    #expect(geometryBottom.startY == 310)
}

@Test("水平エッジ近くのターミナル ブロッカーが外側への再ルートに切り替わります")
func test_routeGeometry_withTerminalBlocker_switchesToOutwardVerticalReroute() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID: [CanvasNodeID: CanvasNode] = [
        parentID: makeNode(id: parentID, x: 40, y: 180, width: 220, height: 220),
        childID: makeNode(id: childID, x: 760, y: 180, width: 220, height: 220),
        blockerID: makeNode(id: blockerID, x: 300, y: 140, width: 220, height: 220),
    ]

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )

    #expect(geometry.axis == .vertical)
    #expect(geometry.startY == 180 || geometry.startY == 400)
    #expect(geometry.endY == 180 || geometry.endY == 400)
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
