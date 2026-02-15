import Application
import Domain
import Testing

// Background: Add-node behavior defines the default placement baseline for new graph edits.
// Responsibility: Verify add-node creation and area-based overlap handling behavior.
@Test("ApplyCanvasCommandsUseCase: addNode creates one text node")
func test_apply_addNode_createsTextNode() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    let result = try await sut.apply(commands: [.addNode])

    #expect(result.newState.nodesByID.count == 1)
    let node = try #require(result.newState.nodesByID.values.first)
    #expect(node.kind == .text)
    #expect(node.bounds.width == 220)
    #expect(node.bounds.height == 120)
    #expect(result.newState.focusedNodeID == node.id)
}

@Test("ApplyCanvasCommandsUseCase: addNode twice creates two nodes")
func test_apply_addNodeTwice_createsTwoNodes() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.apply(commands: [.addNode])
    let second = try await sut.apply(commands: [.addNode])

    #expect(second.newState.nodesByID.count == 2)
    let focusedNodeID = try #require(second.newState.focusedNodeID)
    #expect(second.newState.nodesByID[focusedNodeID] != nil)
}

@Test("ApplyCanvasCommandsUseCase: addNode places node below focused node")
func test_apply_addNode_placesNodeBelowFocusedNode() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 140, y: 120, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addNode])

    #expect(result.newState.nodesByID.count == 2)
    let newNodeID = try #require(result.newState.focusedNodeID)
    let newNode = try #require(result.newState.nodesByID[newNodeID])
    let focusedNodeAfter = try #require(result.newState.nodesByID[focusedNodeID])
    #expect(newNode.bounds.x == focusedNodeAfter.bounds.x)
    #expect(newNode.bounds.y > focusedNodeAfter.bounds.y)
    #expect(boundsOverlap(newNode.bounds, focusedNodeAfter.bounds, spacing: 32) == false)
}

@Test("ApplyCanvasCommandsUseCase: addNode resolves overlap by moving both areas")
func test_apply_addNode_resolvesOverlapByMovingBothAreas() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let blockerNodeID = CanvasNodeID(rawValue: "blocker")
    let focusedNode = CanvasNode(
        id: focusedNodeID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 120, width: 220, height: 120)
    )
    let blockerNode = CanvasNode(
        id: blockerNodeID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 250, width: 220, height: 120)
    )
    let graph = CanvasGraph(
        nodesByID: [focusedNodeID: focusedNode, blockerNodeID: blockerNode],
        edgesByID: [:],
        focusedNodeID: focusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addNode])

    #expect(result.newState.nodesByID.count == 3)
    let newNodeID = try #require(result.newState.focusedNodeID)
    let newNode = try #require(result.newState.nodesByID[newNodeID])
    let blockerAfter = try #require(result.newState.nodesByID[blockerNodeID])

    #expect(newNode.bounds.x != 140 || newNode.bounds.y != 264)
    #expect(blockerAfter.bounds.x != 140 || blockerAfter.bounds.y != 250)
    #expect(newNode.bounds.y < 394)
    #expect(boundsOverlap(newNode.bounds, blockerAfter.bounds, spacing: 32) == false)
}

@Test("ApplyCanvasCommandsUseCase: addNode keeps new node below focused area")
func test_apply_addNode_keepsNewNodeBelowFocusedArea() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let descendantNodeID = CanvasNodeID(rawValue: "descendant")
    let edgeID = CanvasEdgeID(rawValue: "edge-focused-descendant")
    let focusedNode = CanvasNode(
        id: focusedNodeID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 0, width: 220, height: 120)
    )
    let descendantNode = CanvasNode(
        id: descendantNodeID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 420, y: 400, width: 220, height: 120)
    )
    let graph = CanvasGraph(
        nodesByID: [focusedNodeID: focusedNode, descendantNodeID: descendantNode],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: focusedNodeID,
                toNodeID: descendantNodeID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: focusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addNode])

    let newNodeID = try #require(result.newState.focusedNodeID)
    let newNode = try #require(result.newState.nodesByID[newNodeID])
    let focusedAfter = try #require(result.newState.nodesByID[focusedNodeID])

    #expect(newNode.bounds.x == focusedAfter.bounds.x)
    #expect(newNode.bounds.y > focusedAfter.bounds.y)
    #expect(newNode.bounds.y >= 552)
}

private func boundsOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds, spacing: Double = 0) -> Bool {
    let halfSpacing = max(0, spacing) / 2
    let lhsLeft = lhs.x - halfSpacing
    let lhsTop = lhs.y - halfSpacing
    let lhsRight = lhs.x + lhs.width + halfSpacing
    let lhsBottom = lhs.y + lhs.height + halfSpacing
    let rhsLeft = rhs.x - halfSpacing
    let rhsTop = rhs.y - halfSpacing
    let rhsRight = rhs.x + rhs.width + halfSpacing
    let rhsBottom = rhs.y + rhs.height + halfSpacing

    return lhsLeft < rhsRight
        && lhsRight > rhsLeft
        && lhsTop < rhsBottom
        && lhsBottom > rhsTop
}
