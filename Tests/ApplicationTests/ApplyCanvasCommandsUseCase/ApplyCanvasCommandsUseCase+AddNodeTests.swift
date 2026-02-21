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
    #expect(node.bounds.x == 48)
    #expect(node.bounds.y == 48)
    #expect(node.bounds.width == 220)
    #expect(node.bounds.height == 41)
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

@Test("ApplyCanvasCommandsUseCase: addNode uses bottom-most area parent as insertion anchor")
func test_apply_addNode_usesBottomMostAreaParentAsInsertionAnchor() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let bottomParentID = CanvasNodeID(rawValue: "bottom-parent")
    let bottomChildID = CanvasNodeID(rawValue: "bottom-child")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            ),
            bottomParentID: CanvasNode(
                id: bottomParentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 420, y: 200, width: 220, height: 120)
            ),
            bottomChildID: CanvasNode(
                id: bottomChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 700, y: 380, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-bottom-parent-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-bottom-parent-child"),
                fromNodeID: bottomParentID,
                toNodeID: bottomChildID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: focusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.addNode])

    #expect(result.newState.nodesByID.count == 4)
    let newNodeID = try #require(result.newState.focusedNodeID)
    let newNode = try #require(result.newState.nodesByID[newNodeID])
    #expect(newNode.bounds.x == 420)
    #expect(newNode.bounds.y >= 532)
    #expect(newNode.bounds.y > 160)
}

@Test("ApplyCanvasCommandsUseCase: addNode avoids area overlap at insertion time")
func test_apply_addNode_avoidsAreaOverlapAtInsertionTime() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused-top")
    let bottomParentID = CanvasNodeID(rawValue: "bottom-parent")
    let bottomChildID = CanvasNodeID(rawValue: "bottom-child")
    let blockerNodeID = CanvasNodeID(rawValue: "blocker")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            ),
            bottomParentID: CanvasNode(
                id: bottomParentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 420, y: 200, width: 220, height: 120)
            ),
            bottomChildID: CanvasNode(
                id: bottomChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 700, y: 380, width: 220, height: 120)
            ),
            blockerNodeID: CanvasNode(
                id: blockerNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 420, y: 560, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-bottom-parent-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-bottom-parent-child"),
                fromNodeID: bottomParentID,
                toNodeID: bottomChildID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: focusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.addNode])

    #expect(result.newState.nodesByID.count == 5)
    let newNodeID = try #require(result.newState.focusedNodeID)
    let newNode = try #require(result.newState.nodesByID[newNodeID])
    let blockerAfter = try #require(result.newState.nodesByID[blockerNodeID])
    #expect(newNode.bounds.x == 420)
    #expect(newNode.bounds.y >= 712)
    #expect(blockerAfter.bounds.y == 560)
    #expect(boundsOverlap(newNode.bounds, blockerAfter.bounds, spacing: 32) == false)
}

@Test("ApplyCanvasCommandsUseCase: addNode keeps top-level parent as anchor inside bottom-most area")
func test_apply_addNode_keepsTopLevelParentAsAnchorInsideBottomMostArea() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused-top")
    let parentID = CanvasNodeID(rawValue: "parent")
    let descendantNodeID = CanvasNodeID(rawValue: "descendant")
    let otherNodeID = CanvasNodeID(rawValue: "other")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            ),
            parentID: CanvasNode(
                id: parentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 420, y: 200, width: 220, height: 120)
            ),
            descendantNodeID: CanvasNode(
                id: descendantNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 700, y: 400, width: 220, height: 120)
            ),
            otherNodeID: CanvasNode(
                id: otherNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 900, y: 420, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-parent-descendant"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-parent-descendant"),
                fromNodeID: parentID,
                toNodeID: descendantNodeID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-parent-other"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-parent-other"),
                fromNodeID: parentID,
                toNodeID: otherNodeID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.addNode])

    let newNodeID = try #require(result.newState.focusedNodeID)
    let newNode = try #require(result.newState.nodesByID[newNodeID])
    #expect(newNode.bounds.x == 420)
    #expect(newNode.bounds.y >= 572)
}

@Test("ApplyCanvasCommandsUseCase: addNode chooses area with larger maxY when minY ties")
func test_apply_addNode_choosesAreaWithLargerMaxYWhenMinYTies() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let shortParentID = CanvasNodeID(rawValue: "short-parent")
    let shortChildID = CanvasNodeID(rawValue: "short-child")
    let tallParentID = CanvasNodeID(rawValue: "tall-parent")
    let tallChildID = CanvasNodeID(rawValue: "tall-child")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            ),
            shortParentID: CanvasNode(
                id: shortParentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 100, width: 220, height: 80)
            ),
            shortChildID: CanvasNode(
                id: shortChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 440, y: 220, width: 220, height: 80)
            ),
            tallParentID: CanvasNode(
                id: tallParentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 700, y: 100, width: 220, height: 80)
            ),
            tallChildID: CanvasNode(
                id: tallChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 940, y: 420, width: 220, height: 80)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-short-parent-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-short-parent-child"),
                fromNodeID: shortParentID,
                toNodeID: shortChildID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-tall-parent-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-tall-parent-child"),
                fromNodeID: tallParentID,
                toNodeID: tallChildID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.addNode])

    let newNodeID = try #require(result.newState.focusedNodeID)
    let newNode = try #require(result.newState.nodesByID[newNodeID])
    #expect(newNode.bounds.x == 700)
    #expect(newNode.bounds.y >= 204)
}

@Test("ApplyCanvasCommandsUseCase: addNode fails without focused node when multiple areas exist")
func test_apply_addNode_failsWithoutFocusInMultiAreaGraph() async throws {
    let areaA = CanvasAreaID(rawValue: "area-a")
    let areaB = CanvasAreaID(rawValue: "area-b")
    let graph = CanvasGraph(
        nodesByID: [:],
        edgesByID: [:],
        focusedNodeID: nil,
        areasByID: [
            areaA: CanvasArea(id: areaA, nodeIDs: [], editingMode: .tree),
            areaB: CanvasArea(id: areaB, nodeIDs: [], editingMode: .tree),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    do {
        _ = try await sut.apply(commands: [.addNode])
        Issue.record("Expected areaResolutionAmbiguousForAddNode")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .areaResolutionAmbiguousForAddNode)
    }
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
