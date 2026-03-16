// Background: Phase 2 introduces a canonical legacy polyline before node avoidance changes behavior.
// Responsibility: Lock current legacy polyline, arrow tangent, and label-anchor behavior.
import CoreGraphics
import Domain
import Testing

@testable import InterfaceAdapters

@Test("従来のポリラインは水平エルボ ジオメトリを保持する")
func test_legacyPolylineRoute_horizontal_preservesElbowPoints() {
    let geometry = CanvasEdgeRouting.RouteGeometry(
        axis: .horizontal,
        startX: 300,
        startY: 228,
        branchCoordinate: 350,
        endX: 460,
        endY: 388
    )

    let route = CanvasEdgeRouting.legacyPolylineRoute(routeGeometry: geometry)

    #expect(
        route.points == [
            CGPoint(x: 300, y: 228),
            CGPoint(x: 350, y: 228),
            CGPoint(x: 350, y: 388),
            CGPoint(x: 460, y: 388),
        ])
}

@Test("従来のポリラインは垂直エルボ ジオメトリを保持する")
func test_legacyPolylineRoute_vertical_preservesElbowPoints() {
    let geometry = CanvasEdgeRouting.RouteGeometry(
        axis: .vertical,
        startX: 350,
        startY: 176,
        branchCoordinate: 320,
        endX: 390,
        endY: 420
    )

    let route = CanvasEdgeRouting.legacyPolylineRoute(routeGeometry: geometry)

    #expect(
        route.points == [
            CGPoint(x: 350, y: 176),
            CGPoint(x: 350, y: 320),
            CGPoint(x: 390, y: 320),
            CGPoint(x: 390, y: 420),
        ])
}

@Test("従来のエッジ先端ベクトルはポリライン端子セグメントに従います")
func test_legacyEdgeTipAndVector_tracksPolylineTerminalSegments() {
    let route = CanvasEdgeRouting.PolylineRoute(
        start: CGPoint(x: 300, y: 228),
        bendPoints: [
            CGPoint(x: 350, y: 228),
            CGPoint(x: 350, y: 388),
        ],
        end: CGPoint(x: 460, y: 388)
    )

    let forwardEdge = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-forward"),
        fromNodeID: CanvasNodeID(rawValue: "parent"),
        toNodeID: CanvasNodeID(rawValue: "child"),
        relationType: .normal,
        directionality: .fromTo
    )
    let backwardEdge = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-backward"),
        fromNodeID: CanvasNodeID(rawValue: "parent"),
        toNodeID: CanvasNodeID(rawValue: "child"),
        relationType: .normal,
        directionality: .toFrom
    )

    let forwardTip = CanvasEdgeRouting.legacyEdgeTipAndVector(edge: forwardEdge, polylineRoute: route)
    let backwardTip = CanvasEdgeRouting.legacyEdgeTipAndVector(edge: backwardEdge, polylineRoute: route)

    #expect(forwardTip.tip == route.end)
    #expect(forwardTip.vector == CGVector(dx: 110, dy: 0))
    #expect(backwardTip.tip == route.start)
    #expect(backwardTip.vector == CGVector(dx: -50, dy: 0))
}

@Test("従来のラベルアンカーはレンダリングされたポリラインの中点に従います")
func test_labelAnchor_legacyEdge_usesLegacyPolylineMidpoint() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeLegacyPolylineNode(id: childID, x: 460, y: 360, width: 220, height: 56),
    ])

    let anchor = try #require(
        CanvasEdgeRouting.labelAnchor(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [
                CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .horizontal, direction: 1): 350
            ],
            edgeShapeStyle: .legacy
        )
    )

    #expect(anchor.point == CGPoint(x: 350, y: 338))
    #expect(anchor.tangent == CGVector(dx: 0, dy: 1))
    #expect(anchor.normal == CGVector(dx: -1, dy: 0))
}

@Test("従来の生産ルートは、ブロッカーが存在しない場合、ベース ポリラインを保持する")
func test_legacyPolylineRoute_withoutBlockers_matchesBaseRoute() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeLegacyPolylineNode(id: childID, x: 460, y: 360, width: 220, height: 56),
    ])

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let baseRoute = CanvasEdgeRouting.legacyPolylineRoute(routeGeometry: geometry)
    let productionRoute = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID
    )

    #expect(productionRoute.points == baseRoute.points)
}

@Test("従来のルートは中間の非端点 ブロッカーを回避する")
func test_legacyPolylineRoute_withMiddleBlocker_avoidsNonEndpointNode() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeLegacyPolylineNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeLegacyPolylineNode(id: blockerID, x: 340, y: 260, width: 100, height: 100),
    ])

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let baseRoute = CanvasEdgeRouting.legacyPolylineRoute(routeGeometry: geometry)
    let detouredRoute = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID
    )
    let blockerNode = try #require(nodesByID[blockerID])

    #expect(detouredRoute.start == baseRoute.start)
    #expect(detouredRoute.end == baseRoute.end)
    #expect(!routeIntersectsNode(detouredRoute, node: blockerNode, padding: 18))
}

@Test("レガシールートはスタートブロッカーとミドルブロッカーを乗り越えます")
func test_legacyPolylineRoute_withStartAndMiddleBlockers_returnsNonIntersectingPolyline() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let startBlockerID = CanvasNodeID(rawValue: "start-blocker")
    let middleBlockerID = CanvasNodeID(rawValue: "middle-blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeLegacyPolylineNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeLegacyPolylineNode(id: startBlockerID, x: 320, y: 180, width: 80, height: 110),
        makeLegacyPolylineNode(id: middleBlockerID, x: 340, y: 260, width: 100, height: 100),
    ])

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let baseRoute = CanvasEdgeRouting.legacyPolylineRoute(routeGeometry: geometry)
    let detouredRoute = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID
    )

    #expect(detouredRoute.start == baseRoute.start)
    #expect(detouredRoute.end == baseRoute.end)
    #expect(!routeIntersectsNode(detouredRoute, node: try #require(nodesByID[startBlockerID]), padding: 18))
    #expect(!routeIntersectsNode(detouredRoute, node: try #require(nodesByID[middleBlockerID]), padding: 18))
}

@Test("従来の迂回ラベルアンカーはレンダリングされたポリライン上に留まります")
func test_labelAnchor_legacyDetouredEdge_staysOnDetouredPolyline() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeLegacyPolylineNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeLegacyPolylineNode(id: blockerID, x: 340, y: 260, width: 100, height: 100),
    ])

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let route = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID
    )
    let anchor = try #require(
        CanvasEdgeRouting.labelAnchor(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            edgeShapeStyle: .legacy
        )
    )

    #expect(anchor.point != CGPoint(x: 380, y: 308))
    #expect(pointLiesOnRoute(route, point: anchor.point))
    #expect(abs(anchor.tangent.dx) == 1 || abs(anchor.tangent.dy) == 1)
}

@Test("従来の迂回エッジ先端はレンダリングされた端子セグメントに続きます")
func test_edgeTipAndVector_legacyDetouredEdge_tracksRenderedTerminalSegment() throws {
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
        makeLegacyPolylineNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeLegacyPolylineNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeLegacyPolylineNode(id: blockerID, x: 340, y: 260, width: 100, height: 100),
    ])

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let route = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID
    )
    let tipAndVector = try #require(
        CanvasEdgeRouting.edgeTipAndVector(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            edgeShapeStyle: .legacy
        )
    )

    #expect(tipAndVector.tip == route.end)
    #expect(
        tipAndVector.vector
            == CGVector(
                dx: route.end.x - route.pointBeforeEnd.x,
                dy: route.end.y - route.pointBeforeEnd.y
            )
    )
}

@Test("垂直の従来のルートはミドルブロッカーを回避し、ラベルアンカーを迂回に保ちます")
func test_legacyPolylineRoute_verticalWithMiddleBlocker_avoidsNodeAndKeepsAnchor() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 240, y: 80, width: 120, height: 140),
        makeLegacyPolylineNode(id: childID, x: 300, y: 460, width: 120, height: 140),
        makeLegacyPolylineNode(id: blockerID, x: 260, y: 260, width: 110, height: 110),
    ])
    let branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double] = [
        CanvasEdgeRouting.BranchKey(parentNodeID: parentID, axis: .vertical, direction: 1): 320
    ]

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
        )
    )
    let detouredRoute = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID
    )
    let anchor = try #require(
        CanvasEdgeRouting.labelAnchor(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
            edgeShapeStyle: .legacy
        )
    )

    #expect(!routeIntersectsNode(detouredRoute, node: try #require(nodesByID[blockerID]), padding: 18))
    #expect(pointLiesOnRoute(detouredRoute, point: anchor.point))
    #expect(abs(anchor.tangent.dx) == 1 || abs(anchor.tangent.dy) == 1)
}

@Test("従来の兄弟ノードのルートは、ブロッカーを迂回するときにレーンの順序を維持する")
func test_legacyPolylineRoute_withSiblingBlocker_preservesLaneOrderingNearEndpoints() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let upperChildID = CanvasNodeID(rawValue: "upper-child")
    let lowerChildID = CanvasNodeID(rawValue: "lower-child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let upperEdge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-upper"), fromNodeID: parentID, toNodeID: upperChildID)
    let lowerEdge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-lower"), fromNodeID: parentID, toNodeID: lowerChildID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 80, y: 220, width: 220, height: 220),
        makeLegacyPolylineNode(id: upperChildID, x: 460, y: 120, width: 220, height: 220),
        makeLegacyPolylineNode(id: lowerChildID, x: 460, y: 420, width: 220, height: 220),
        makeLegacyPolylineNode(id: blockerID, x: 340, y: 260, width: 120, height: 220),
    ])
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
    let upperRoute = CanvasEdgeRouting.legacyPolylineRoute(
        for: upperEdge,
        routeGeometry: upperGeometry,
        nodesByID: nodesByID
    )
    let lowerRoute = CanvasEdgeRouting.legacyPolylineRoute(
        for: lowerEdge,
        routeGeometry: lowerGeometry,
        nodesByID: nodesByID
    )

    #expect(upperRoute.start.y < lowerRoute.start.y)
    #expect(upperRoute.pointAfterStart.y < lowerRoute.pointAfterStart.y)
    #expect(upperRoute.end.y < lowerRoute.end.y)
    #expect(!routeIntersectsNode(upperRoute, node: try #require(nodesByID[blockerID]), padding: 18))
    #expect(!routeIntersectsNode(lowerRoute, node: try #require(nodesByID[blockerID]), padding: 18))
    #expect(!routesIntersect(upperRoute, lowerRoute))
}

@Test("従来の迂回は、ブロッカー辞書の順序に関係なく安定したままになる")
func test_legacyPolylineRoute_withSymmetricBlockers_isIndependentFromDictionaryOrder() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let topBlockerID = CanvasNodeID(rawValue: "blocker-top")
    let bottomBlockerID = CanvasNodeID(rawValue: "blocker-bottom")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let firstNodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeLegacyPolylineNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeLegacyPolylineNode(id: topBlockerID, x: 320, y: 220, width: 120, height: 80),
        makeLegacyPolylineNode(id: bottomBlockerID, x: 320, y: 300, width: 120, height: 80),
    ])
    let secondNodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: bottomBlockerID, x: 320, y: 300, width: 120, height: 80),
        makeLegacyPolylineNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeLegacyPolylineNode(id: topBlockerID, x: 320, y: 220, width: 120, height: 80),
        makeLegacyPolylineNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
    ])

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: firstNodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let firstRoute = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: firstNodesByID
    )
    let secondRoute = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: secondNodesByID
    )

    #expect(firstRoute.points == secondRoute.points)
}

@Test("従来のルートは別の側にルート変更することでターミナル ブロッカーを回避する")
func test_legacyPolylineRoute_withTerminalBlocker_avoidsByChangingAnchors() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 40, y: 180, width: 220, height: 220),
        makeLegacyPolylineNode(id: childID, x: 760, y: 180, width: 220, height: 220),
        makeLegacyPolylineNode(id: blockerID, x: 300, y: 140, width: 220, height: 220),
    ])

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let route = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID
    )

    #expect(!routeIntersectsNode(route, node: try #require(nodesByID[blockerID]), padding: 18))
}

@Test("重複した再ルーティングされたレガシー エッジにより、外側のブランチが分離されたままになる")
func test_legacyPolylineRoute_withDuplicatedTerminalBlocker_keepsSeparatedRoutes() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edgeA = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-a"), fromNodeID: parentID, toNodeID: childID)
    let edgeB = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-b"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 40, y: 180, width: 220, height: 220),
        makeLegacyPolylineNode(id: childID, x: 760, y: 180, width: 220, height: 220),
        makeLegacyPolylineNode(id: blockerID, x: 300, y: 140, width: 220, height: 220),
    ])
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(edges: [edgeA, edgeB], nodesByID: nodesByID)

    let routeA = CanvasEdgeRouting.legacyPolylineRoute(
        for: edgeA,
        routeGeometry: try #require(
            CanvasEdgeRouting.routeGeometry(
                for: edgeA,
                nodesByID: nodesByID,
                branchCoordinateByParentAndDirection: [:],
                laneOffsetsByEdgeID: laneOffsetsByEdgeID
            )
        ),
        nodesByID: nodesByID
    )
    let routeB = CanvasEdgeRouting.legacyPolylineRoute(
        for: edgeB,
        routeGeometry: try #require(
            CanvasEdgeRouting.routeGeometry(
                for: edgeB,
                nodesByID: nodesByID,
                branchCoordinateByParentAndDirection: [:],
                laneOffsetsByEdgeID: laneOffsetsByEdgeID
            )
        ),
        nodesByID: nodesByID
    )

    #expect(!routeIntersectsNode(routeA, node: try #require(nodesByID[blockerID]), padding: 18))
    #expect(!routeIntersectsNode(routeB, node: try #require(nodesByID[blockerID]), padding: 18))
    #expect(routeA.points != routeB.points)
    #expect(!routesIntersect(routeA, routeB))
}

@Test("従来のリルートは、上部と下部がブロックされている場合、同じ軸の外側パスにフォールバックする")
func test_legacyPolylineRoute_withVerticalReroutesBlocked_usesSameAxisOutwardFallback() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let middleBlockerID = CanvasNodeID(rawValue: "middle-blocker")
    let topBlockerID = CanvasNodeID(rawValue: "top-blocker")
    let bottomBlockerID = CanvasNodeID(rawValue: "bottom-blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 320, y: 180, width: 220, height: 220),
        makeLegacyPolylineNode(id: childID, x: 760, y: 180, width: 220, height: 220),
        makeLegacyPolylineNode(id: middleBlockerID, x: 560, y: 220, width: 120, height: 140),
        makeLegacyPolylineNode(id: topBlockerID, x: 260, y: 20, width: 780, height: 140),
        makeLegacyPolylineNode(id: bottomBlockerID, x: 260, y: 420, width: 780, height: 140),
    ])

    let geometry = try #require(
        CanvasEdgeRouting.routeGeometry(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:]
        )
    )
    let route = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID
    )

    #expect(geometry.axis == .horizontal)
    #expect(!routeIntersectsNode(route, node: try #require(nodesByID[middleBlockerID]), padding: 18))
    #expect(!routeIntersectsNode(route, node: try #require(nodesByID[topBlockerID]), padding: 18))
    #expect(!routeIntersectsNode(route, node: try #require(nodesByID[bottomBlockerID]), padding: 18))
}

@Test("レガシー ノードの回避を無効にすることができ、ベースのポリラインを維持する")
func test_legacyPolylineRoute_whenNodeAvoidanceDisabled_keepsBaseRoute() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edge = CanvasEdge(id: CanvasEdgeID(rawValue: "edge-1"), fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLegacyPolylineNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeLegacyPolylineNode(id: childID, x: 460, y: 360, width: 220, height: 56),
        makeLegacyPolylineNode(id: blockerID, x: 300, y: 140, width: 220, height: 220),
    ])
    let geometry = CanvasEdgeRouting.RouteGeometry(
        axis: .horizontal,
        startX: 300,
        startY: 228,
        branchCoordinate: 350,
        endX: 460,
        endY: 388
    )
    let baseRoute = CanvasEdgeRouting.legacyPolylineRoute(routeGeometry: geometry)
    let routeWithoutAvoidance = CanvasEdgeRouting.legacyPolylineRoute(
        for: edge,
        routeGeometry: geometry,
        nodesByID: nodesByID,
        nodeAvoidanceEnabled: false
    )

    #expect(routeIntersectsNode(baseRoute, node: try #require(nodesByID[blockerID]), padding: 18))
    #expect(routeWithoutAvoidance.points == baseRoute.points)
    #expect(routeIntersectsNode(routeWithoutAvoidance, node: try #require(nodesByID[blockerID]), padding: 18))
}
