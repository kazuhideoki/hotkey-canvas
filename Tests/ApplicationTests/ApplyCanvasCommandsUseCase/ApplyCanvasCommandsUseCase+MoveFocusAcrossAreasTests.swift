import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: moveFocusAcrossAreasToRoot in node target picks destination tree root")
func test_apply_moveFocusAcrossAreasToRoot_nodeTarget_picksDestinationTreeRoot() async throws {
    let fixture = makeTreeAcrossAreasFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    let result = try await sut.apply(commands: [.moveFocusAcrossAreasToRoot(.right)])

    #expect(result.newState.focusedNodeID == fixture.expectedFocusedNodeID)
    #expect(result.newState.focusedElement == .node(fixture.expectedFocusedNodeID))
    #expect(result.newState.selectedNodeIDs == [fixture.expectedFocusedNodeID])
}

@Test("ApplyCanvasCommandsUseCase: moveFocusAcrossAreasToRoot in node target picks oldest created diagram node")
func test_apply_moveFocusAcrossAreasToRoot_nodeTarget_picksOldestDiagramNode() async throws {
    let fixture = makeDiagramAcrossAreasFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    let result = try await sut.apply(commands: [.moveFocusAcrossAreasToRoot(.right)])

    #expect(result.newState.focusedNodeID == fixture.expectedFocusedNodeID)
    #expect(result.newState.focusedElement == .node(fixture.expectedFocusedNodeID))
    #expect(result.newState.selectedNodeIDs == [fixture.expectedFocusedNodeID])
}

@Test("ApplyCanvasCommandsUseCase: moveFocusAcrossAreasToRoot in area target keeps area focus and updates anchor")
func test_apply_moveFocusAcrossAreasToRoot_areaTarget_keepsAreaFocusAndUpdatesAnchor() async throws {
    let fixture = makeAreaTargetAcrossAreasFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    let result = try await sut.apply(commands: [.moveFocusAcrossAreasToRoot(.right)])

    #expect(result.newState.focusedNodeID == fixture.expectedFocusedNodeID)
    #expect(result.newState.focusedElement == .area(fixture.expectedFocusedAreaID))
    #expect(result.newState.selectedNodeIDs == [fixture.expectedFocusedNodeID])
}

@Test("ApplyCanvasCommandsUseCase: moveFocusAcrossAreasToRoot wraps from right edge to left-most area")
func test_apply_moveFocusAcrossAreasToRoot_wrapsRightEdgeToLeftMostArea() async throws {
    let fixture = makeDiagramAcrossAreasFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    let firstMove = try await sut.apply(commands: [.moveFocusAcrossAreasToRoot(.right)])
    let wrappedMove = try await ApplyCanvasCommandsUseCase(initialGraph: firstMove.newState).apply(
        commands: [.moveFocusAcrossAreasToRoot(.right)]
    )

    #expect(wrappedMove.newState.focusedNodeID == CanvasNodeID(rawValue: "left-node"))
    #expect(wrappedMove.newState.focusedElement == .node(CanvasNodeID(rawValue: "left-node")))
}

@Test("ApplyCanvasCommandsUseCase: moveFocusAcrossAreasToRoot wraps from left edge to right-most area")
func test_apply_moveFocusAcrossAreasToRoot_wrapsLeftEdgeToRightMostArea() async throws {
    let fixture = makeDiagramAcrossAreasFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    let moved = try await sut.apply(commands: [.moveFocusAcrossAreasToRoot(.left)])

    #expect(moved.newState.focusedNodeID == CanvasNodeID(rawValue: "right-old"))
    #expect(moved.newState.focusedElement == .node(CanvasNodeID(rawValue: "right-old")))
}

private struct AcrossAreasFixture {
    let graph: CanvasGraph
    let expectedFocusedNodeID: CanvasNodeID
    let expectedFocusedAreaID: CanvasAreaID
}

private func makeTreeAcrossAreasFixture() -> AcrossAreasFixture {
    let leftRootID = CanvasNodeID(rawValue: "left-root")
    let leftChildID = CanvasNodeID(rawValue: "left-child")
    let rightRootID = CanvasNodeID(rawValue: "right-root")
    let rightChildID = CanvasNodeID(rawValue: "right-child")
    let leftAreaID = CanvasAreaID(rawValue: "left-area")
    let rightAreaID = CanvasAreaID(rawValue: "right-area")

    let graph = CanvasGraph(
        nodesByID: [
            leftRootID: makeNode(id: leftRootID, x: 0, y: 0, createdOrder: 0),
            leftChildID: makeNode(id: leftChildID, x: 180, y: 120, createdOrder: 1),
            rightRootID: makeNode(id: rightRootID, x: 500, y: 80, createdOrder: 2),
            rightChildID: makeNode(id: rightChildID, x: 660, y: 220, createdOrder: 3),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-left-root-child"):
                makeParentChildEdge(id: "edge-left-root-child", from: leftRootID, to: leftChildID),
            CanvasEdgeID(rawValue: "edge-right-root-child"):
                makeParentChildEdge(id: "edge-right-root-child", from: rightRootID, to: rightChildID),
        ],
        focusedNodeID: leftChildID,
        focusedElement: .node(leftChildID),
        selectedNodeIDs: [leftChildID],
        areasByID: [
            leftAreaID: CanvasArea(id: leftAreaID, nodeIDs: [leftRootID, leftChildID], editingMode: .tree),
            rightAreaID: CanvasArea(id: rightAreaID, nodeIDs: [rightRootID, rightChildID], editingMode: .tree),
        ]
    )
    return AcrossAreasFixture(graph: graph, expectedFocusedNodeID: rightRootID, expectedFocusedAreaID: rightAreaID)
}

private func makeDiagramAcrossAreasFixture() -> AcrossAreasFixture {
    let leftNodeID = CanvasNodeID(rawValue: "left-node")
    let rightOldID = CanvasNodeID(rawValue: "right-old")
    let rightNewID = CanvasNodeID(rawValue: "right-new")
    let leftAreaID = CanvasAreaID(rawValue: "left-area")
    let rightAreaID = CanvasAreaID(rawValue: "right-area")

    let graph = CanvasGraph(
        nodesByID: [
            leftNodeID: makeNode(id: leftNodeID, x: 0, y: 0, createdOrder: 0),
            rightOldID: makeNode(id: rightOldID, x: 600, y: 260, createdOrder: 1),
            rightNewID: makeNode(id: rightNewID, x: 520, y: 20, createdOrder: 2),
        ],
        edgesByID: [:],
        focusedNodeID: leftNodeID,
        focusedElement: .node(leftNodeID),
        selectedNodeIDs: [leftNodeID],
        areasByID: [
            leftAreaID: CanvasArea(id: leftAreaID, nodeIDs: [leftNodeID], editingMode: .diagram),
            rightAreaID: CanvasArea(id: rightAreaID, nodeIDs: [rightOldID, rightNewID], editingMode: .diagram),
        ]
    )
    return AcrossAreasFixture(graph: graph, expectedFocusedNodeID: rightOldID, expectedFocusedAreaID: rightAreaID)
}

private func makeAreaTargetAcrossAreasFixture() -> AcrossAreasFixture {
    let leftNodeID = CanvasNodeID(rawValue: "left-node")
    let rightNodeID = CanvasNodeID(rawValue: "right-node")
    let leftAreaID = CanvasAreaID(rawValue: "left-area")
    let rightAreaID = CanvasAreaID(rawValue: "right-area")

    let graph = CanvasGraph(
        nodesByID: [
            leftNodeID: makeNode(id: leftNodeID, x: 0, y: 0, createdOrder: 0),
            rightNodeID: makeNode(id: rightNodeID, x: 520, y: 40, createdOrder: 1),
        ],
        edgesByID: [:],
        focusedNodeID: leftNodeID,
        focusedElement: .area(leftAreaID),
        selectedNodeIDs: [leftNodeID],
        areasByID: [
            leftAreaID: CanvasArea(id: leftAreaID, nodeIDs: [leftNodeID], editingMode: .diagram),
            rightAreaID: CanvasArea(id: rightAreaID, nodeIDs: [rightNodeID], editingMode: .diagram),
        ]
    )
    return AcrossAreasFixture(graph: graph, expectedFocusedNodeID: rightNodeID, expectedFocusedAreaID: rightAreaID)
}

private func makeNode(id: CanvasNodeID, x: Double, y: Double, createdOrder: Int) -> CanvasNode {
    CanvasNode(
        id: id,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: x, y: y, width: 120, height: 80),
        metadata: ["createdOrder": String(createdOrder)]
    )
}

private func makeParentChildEdge(id: String, from: CanvasNodeID, to: CanvasNodeID) -> CanvasEdge {
    CanvasEdge(
        id: CanvasEdgeID(rawValue: id),
        fromNodeID: from,
        toNodeID: to,
        relationType: .parentChild,
        parentChildOrder: 0
    )
}
