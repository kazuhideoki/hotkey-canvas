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

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode removes selected subtrees in tree area")
func test_apply_deleteFocusedNode_removesSelectedSubtreesInTreeArea() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let focusedChildID = CanvasNodeID(rawValue: "focused-child")
    let siblingID = CanvasNodeID(rawValue: "sibling")
    let survivorID = CanvasNodeID(rawValue: "survivor")
    let graph = makeTreeSelectionDeleteGraph(
        rootID: rootID,
        focusedID: focusedID,
        focusedChildID: focusedChildID,
        siblingID: siblingID,
        survivorID: survivorID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[rootID] != nil)
    #expect(result.newState.nodesByID[survivorID] != nil)
    #expect(result.newState.nodesByID[focusedID] == nil)
    #expect(result.newState.nodesByID[focusedChildID] == nil)
    #expect(result.newState.nodesByID[siblingID] == nil)
    #expect(result.newState.focusedNodeID == survivorID)
    #expect(result.newState.selectedNodeIDs == [survivorID])
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode removes selected nodes in diagram area")
func test_apply_deleteFocusedNode_removesSelectedNodesInDiagramArea() async throws {
    let leftID = CanvasNodeID(rawValue: "left")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let rightID = CanvasNodeID(rawValue: "right")
    let areaID = CanvasAreaID(rawValue: "diagram-area")

    let graph = CanvasGraph(
        nodesByID: [
            leftID: CanvasNode(
                id: leftID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 300, y: 0, width: 220, height: 220)
            ),
            rightID: CanvasNode(
                id: rightID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 600, y: 0, width: 220, height: 220)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-left-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-left-focused"),
                fromNodeID: leftID,
                toNodeID: focusedID,
                relationType: .normal
            ),
            CanvasEdgeID(rawValue: "edge-focused-right"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-focused-right"),
                fromNodeID: focusedID,
                toNodeID: rightID,
                relationType: .normal
            ),
        ],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, rightID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [leftID, focusedID, rightID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[leftID] != nil)
    #expect(result.newState.nodesByID[focusedID] == nil)
    #expect(result.newState.nodesByID[rightID] == nil)
    #expect(result.newState.focusedNodeID == leftID)
    #expect(result.newState.selectedNodeIDs == [leftID])
    #expect(result.newState.areasByID[areaID]?.nodeIDs == [leftID])
}

private func makeTreeSelectionDeleteGraph(
    rootID: CanvasNodeID,
    focusedID: CanvasNodeID,
    focusedChildID: CanvasNodeID,
    siblingID: CanvasNodeID,
    survivorID: CanvasNodeID
) -> CanvasGraph {
    CanvasGraph(
        nodesByID: [
            rootID: makeTreeSelectionDeleteNode(id: rootID, x: 0, y: 0),
            focusedID: makeTreeSelectionDeleteNode(id: focusedID, x: 200, y: 120),
            focusedChildID: makeTreeSelectionDeleteNode(id: focusedChildID, x: 400, y: 120),
            siblingID: makeTreeSelectionDeleteNode(id: siblingID, x: 200, y: 260),
            survivorID: makeTreeSelectionDeleteNode(id: survivorID, x: 0, y: 260),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-focused"),
                fromNodeID: rootID,
                toNodeID: focusedID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-focused-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-focused-child"),
                fromNodeID: focusedID,
                toNodeID: focusedChildID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-sibling"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-sibling"),
                fromNodeID: rootID,
                toNodeID: siblingID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-survivor"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-survivor"),
                fromNodeID: rootID,
                toNodeID: survivorID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, siblingID]
    )
}

private func makeTreeSelectionDeleteNode(id: CanvasNodeID, x: Double, y: Double) -> CanvasNode {
    CanvasNode(
        id: id,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: x, y: y, width: 100, height: 80)
    )
}
