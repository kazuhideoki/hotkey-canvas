import Application
import Domain
import Testing

// Background: Deleting focused nodes drives destructive edit flows and subtree cleanup.
// Responsibility: Verify focused deletion behavior, no-op guards, and subtree removal.
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
            ),
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
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[targetID] == nil)
    #expect(result.newState.nodesByID[otherID] != nil)
    #expect(result.newState.edgesByID[edgeID] == nil)
    #expect(result.newState.focusedNodeID == otherID)
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode fails when focus is nil")
func test_apply_deleteFocusedNode_fails_whenFocusedNodeIDIsNil() async throws {
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
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    do {
        _ = try await sut.apply(commands: [.deleteFocusedNode])
        Issue.record("Expected focusedNodeNotFound")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .focusedNodeNotFound)
    }
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode fails when focused node is stale")
func test_apply_deleteFocusedNode_fails_whenFocusedNodeIDIsStale() async throws {
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
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    do {
        _ = try await sut.apply(commands: [.deleteFocusedNode])
        Issue.record("Expected focusedNodeNotFound")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .focusedNodeNotFound)
    }
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode removes focused subtree")
func test_apply_deleteFocusedNode_removesFocusedSubtree() async throws {
    let fixture = SubtreeDeletionFixture.make()
    let graph = CanvasGraph(
        nodesByID: fixture.nodesByID,
        edgesByID: fixture.edgesByID,
        focusedNodeID: fixture.childID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[fixture.childID] == nil)
    #expect(result.newState.nodesByID[fixture.grandchildID] == nil)
    #expect(result.newState.nodesByID[fixture.rootID] != nil)
    #expect(result.newState.nodesByID[fixture.siblingID] != nil)
    #expect(result.newState.edgesByID[fixture.edgeRootChildID] == nil)
    #expect(result.newState.edgesByID[fixture.edgeChildGrandchildID] == nil)
    #expect(result.newState.edgesByID[fixture.edgeRootSiblingID] != nil)
}
