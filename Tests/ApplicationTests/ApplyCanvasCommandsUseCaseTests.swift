import Application
import Domain
import Testing

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
    #expect(newNode.bounds.x == 140)
    #expect(newNode.bounds.y == 264)
}

@Test("ApplyCanvasCommandsUseCase: addNode skips occupied space below focused node")
func test_apply_addNode_skipsOccupiedSpaceBelowFocusedNode() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let blockerNodeID = CanvasNodeID(rawValue: "blocker")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 140, y: 120, width: 220, height: 120)
            ),
            blockerNodeID: CanvasNode(
                id: blockerNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 140, y: 250, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addNode])

    #expect(result.newState.nodesByID.count == 3)
    let newNodeID = try #require(result.newState.focusedNodeID)
    let newNode = try #require(result.newState.nodesByID[newNodeID])
    #expect(newNode.bounds.x == 140)
    #expect(newNode.bounds.y == 394)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus picks nearest node in requested direction")
func test_apply_moveFocus_movesToNearestNodeInDirection() async throws {
    let centerID = CanvasNodeID(rawValue: "center")
    let rightNearID = CanvasNodeID(rawValue: "right-near")
    let rightFarID = CanvasNodeID(rawValue: "right-far")

    let graph = CanvasGraph(
        nodesByID: [
            centerID: CanvasNode(
                id: centerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            rightNearID: CanvasNode(
                id: rightNearID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 100, width: 100, height: 100)
            ),
            rightFarID: CanvasNode(
                id: rightFarID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 420, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: centerID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveFocus(.right)])

    #expect(result.newState.focusedNodeID == rightNearID)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus keeps focus when direction has no candidate")
func test_apply_moveFocus_keepsCurrentFocus_whenNoCandidateExists() async throws {
    let singleNodeID = CanvasNodeID(rawValue: "single")
    let graph = CanvasGraph(
        nodesByID: [
            singleNodeID: CanvasNode(
                id: singleNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: singleNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveFocus(.left)])

    #expect(result.newState.focusedNodeID == singleNodeID)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus assigns fallback focus when focus is nil")
func test_apply_moveFocus_assignsFallbackFocus_whenFocusedNodeIDIsNil() async throws {
    let singleNodeID = CanvasNodeID(rawValue: "single")
    let graph = CanvasGraph(
        nodesByID: [
            singleNodeID: CanvasNode(
                id: singleNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nil
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveFocus(.left)])

    #expect(result.newState.focusedNodeID == singleNodeID)
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode removes focused node")
func test_apply_deleteFocusedNode_removesFocusedNode() async throws {
    let targetID = CanvasNodeID(rawValue: "target")
    let otherID = CanvasNodeID(rawValue: "other")
    let edgeID = CanvasEdgeID(rawValue: "edge")

    let graph = CanvasGraph(
        nodesByID: [
            targetID: CanvasNode(
                id: targetID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            otherID: CanvasNode(
                id: otherID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 280, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: targetID,
                toNodeID: otherID,
                relationType: .normal
            )
        ],
        focusedNodeID: targetID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[targetID] == nil)
    #expect(result.newState.nodesByID[otherID] != nil)
    #expect(result.newState.edgesByID[edgeID] == nil)
    #expect(result.newState.focusedNodeID == otherID)
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode is no-op when focus is nil")
func test_apply_deleteFocusedNode_isNoOp_whenFocusedNodeIDIsNil() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nil
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState == graph)
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode is no-op when focused node is stale")
func test_apply_deleteFocusedNode_isNoOp_whenFocusedNodeIDIsStale() async throws {
    let existingNodeID = CanvasNodeID(rawValue: "node")
    let staleFocusedNodeID = CanvasNodeID(rawValue: "stale")
    let graph = CanvasGraph(
        nodesByID: [
            existingNodeID: CanvasNode(
                id: existingNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: staleFocusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState == graph)
}
