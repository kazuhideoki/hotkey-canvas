import Application
import Domain
import Testing

// Background: Add-node behavior defines the default placement baseline for new graph edits.
// Responsibility: Verify add-node creation and vertical collision-avoidance behavior.
@Test("ApplyCanvasCommandsUseCase: addNode creates one text node")
func test_apply_addNode_createsTextNode() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    let result = try await sut.apply(commands: [.addNode])

    #expect(result.newState.nodesByID.count == 1)
    let node = try #require(result.newState.nodesByID.values.first)
    #expect(node.kind == .text)
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
