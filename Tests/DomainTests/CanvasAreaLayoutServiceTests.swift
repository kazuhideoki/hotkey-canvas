// Background: Area-based layout is the foundation of hierarchy-aware overlap avoidance.
// Responsibility: Verify connected-area extraction and deterministic overlap resolution behavior.
import Domain
import Testing

@Test("CanvasAreaLayoutService: parent-child areas are connected components")
func test_makeParentChildAreas_buildsConnectedComponents() {
    let fixture = makeParentChildAreasFixture()
    let areas = CanvasAreaLayoutService.makeParentChildAreas(in: fixture.graph)

    #expect(areas.count == 2)
    guard let connectedArea = areas.first(where: { $0.nodeIDs.contains(fixture.connectedAreaID) }) else {
        Issue.record("connected area not found")
        return
    }
    #expect(connectedArea.nodeIDs == fixture.connectedNodeIDs)
    #expect(connectedArea.id == fixture.connectedAreaID)
    expectAlmostEqual(connectedArea.bounds.minX, 0)
    expectAlmostEqual(connectedArea.bounds.minY, 0)
    expectAlmostEqual(connectedArea.bounds.width, 400)
    expectAlmostEqual(connectedArea.bounds.height, 120)

    guard let isolatedArea = areas.first(where: { $0.nodeIDs == Set([fixture.isolatedAreaID]) }) else {
        Issue.record("isolated area not found")
        return
    }
    #expect(isolatedArea.id == fixture.isolatedAreaID)
    expectAlmostEqual(isolatedArea.bounds.minX, -200)
    expectAlmostEqual(isolatedArea.bounds.minY, 300)
    expectAlmostEqual(isolatedArea.bounds.width, 120)
    expectAlmostEqual(isolatedArea.bounds.height, 90)
}

@Test("CanvasAreaLayoutService: initial collision moves seed and first collided area equally")
func test_resolveOverlaps_initialCollision_movesBothAreasEqually() {
    let areaA = CanvasNodeArea(
        id: CanvasNodeID(rawValue: "a"),
        nodeIDs: Set([CanvasNodeID(rawValue: "a")]),
        bounds: CanvasRect(minX: 0, minY: 0, width: 100, height: 100)
    )
    let areaB = CanvasNodeArea(
        id: CanvasNodeID(rawValue: "b"),
        nodeIDs: Set([CanvasNodeID(rawValue: "b")]),
        bounds: CanvasRect(minX: 80, minY: 0, width: 100, height: 100)
    )

    let translations = CanvasAreaLayoutService.resolveOverlaps(
        areas: [areaA, areaB],
        seedAreaID: areaA.id
    )

    let translationA = translations[areaA.id] ?? .zero
    let translationB = translations[areaB.id] ?? .zero
    expectAlmostEqual(translationA.dx, -10)
    expectAlmostEqual(translationA.dy, 0)
    expectAlmostEqual(translationB.dx, 10)
    expectAlmostEqual(translationB.dy, 0)
}

@Test("CanvasAreaLayoutService: chain collision moves encountered area only")
func test_resolveOverlaps_chainCollision_movesEncounteredAreaOnly() {
    let areaA = CanvasNodeArea(
        id: CanvasNodeID(rawValue: "a"),
        nodeIDs: Set([CanvasNodeID(rawValue: "a")]),
        bounds: CanvasRect(minX: 0, minY: 0, width: 100, height: 100)
    )
    let areaB = CanvasNodeArea(
        id: CanvasNodeID(rawValue: "b"),
        nodeIDs: Set([CanvasNodeID(rawValue: "b")]),
        bounds: CanvasRect(minX: 80, minY: 0, width: 100, height: 100)
    )
    let areaC = CanvasNodeArea(
        id: CanvasNodeID(rawValue: "c"),
        nodeIDs: Set([CanvasNodeID(rawValue: "c")]),
        bounds: CanvasRect(minX: 170, minY: 0, width: 100, height: 100)
    )

    let translations = CanvasAreaLayoutService.resolveOverlaps(
        areas: [areaA, areaB, areaC],
        seedAreaID: areaA.id
    )

    let translationA = translations[areaA.id] ?? .zero
    let translationB = translations[areaB.id] ?? .zero
    let translationC = translations[areaC.id] ?? .zero
    expectAlmostEqual(translationA.dx, -10)
    expectAlmostEqual(translationA.dy, 0)
    expectAlmostEqual(translationB.dx, 10)
    expectAlmostEqual(translationB.dy, 0)
    expectAlmostEqual(translationC.dx, 20)
    expectAlmostEqual(translationC.dy, 0)
}

@Test("CanvasAreaLayoutService: minimum spacing is included in resolved distance")
func test_resolveOverlaps_withMinimumSpacing_appliesExtraDistance() {
    let areaA = CanvasNodeArea(
        id: CanvasNodeID(rawValue: "a"),
        nodeIDs: Set([CanvasNodeID(rawValue: "a")]),
        bounds: CanvasRect(minX: 0, minY: 0, width: 100, height: 100)
    )
    let areaB = CanvasNodeArea(
        id: CanvasNodeID(rawValue: "b"),
        nodeIDs: Set([CanvasNodeID(rawValue: "b")]),
        bounds: CanvasRect(minX: 80, minY: 0, width: 100, height: 100)
    )

    let translations = CanvasAreaLayoutService.resolveOverlaps(
        areas: [areaA, areaB],
        seedAreaID: areaA.id,
        minimumSpacing: 24
    )

    let translationA = translations[areaA.id] ?? .zero
    let translationB = translations[areaB.id] ?? .zero
    expectAlmostEqual(translationA.dx, -22)
    expectAlmostEqual(translationA.dy, 0)
    expectAlmostEqual(translationB.dx, 22)
    expectAlmostEqual(translationB.dy, 0)
}

@Test("CanvasAreaLayoutService: returns empty result when seed area is missing")
func test_resolveOverlaps_missingSeed_returnsEmpty() {
    let areaA = CanvasNodeArea(
        id: CanvasNodeID(rawValue: "a"),
        nodeIDs: Set([CanvasNodeID(rawValue: "a")]),
        bounds: CanvasRect(minX: 0, minY: 0, width: 100, height: 100)
    )

    let translations = CanvasAreaLayoutService.resolveOverlaps(
        areas: [areaA],
        seedAreaID: CanvasNodeID(rawValue: "missing")
    )

    #expect(translations.isEmpty)
}

private func expectAlmostEqual(_ lhs: Double, _ rhs: Double, tolerance: Double = 0.0001) {
    #expect(abs(lhs - rhs) <= tolerance)
}

private struct ParentChildAreasFixture {
    let graph: CanvasGraph
    let connectedAreaID: CanvasNodeID
    let connectedNodeIDs: Set<CanvasNodeID>
    let isolatedAreaID: CanvasNodeID
}

private func makeParentChildAreasFixture() -> ParentChildAreasFixture {
    let nodeA = CanvasNode(
        id: CanvasNodeID(rawValue: "a"),
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
    )
    let nodeB = CanvasNode(
        id: CanvasNodeID(rawValue: "b"),
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 0, width: 100, height: 80)
    )
    let nodeC = CanvasNode(
        id: CanvasNodeID(rawValue: "c"),
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 300, y: 40, width: 100, height: 80)
    )
    let nodeD = CanvasNode(
        id: CanvasNodeID(rawValue: "d"),
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: -200, y: 300, width: 120, height: 90)
    )

    let edgeAB = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-a-b"),
        fromNodeID: nodeA.id,
        toNodeID: nodeB.id,
        relationType: .parentChild
    )
    let edgeCB = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-c-b"),
        fromNodeID: nodeC.id,
        toNodeID: nodeB.id,
        relationType: .parentChild
    )
    let edgeDA = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-d-a"),
        fromNodeID: nodeD.id,
        toNodeID: nodeA.id,
        relationType: .normal
    )

    let graph = CanvasGraph(
        nodesByID: [nodeA.id: nodeA, nodeB.id: nodeB, nodeC.id: nodeC, nodeD.id: nodeD],
        edgesByID: [edgeAB.id: edgeAB, edgeCB.id: edgeCB, edgeDA.id: edgeDA],
        focusedNodeID: nodeA.id
    )

    return ParentChildAreasFixture(
        graph: graph,
        connectedAreaID: nodeA.id,
        connectedNodeIDs: Set([nodeA.id, nodeB.id, nodeC.id]),
        isolatedAreaID: nodeD.id
    )
}
