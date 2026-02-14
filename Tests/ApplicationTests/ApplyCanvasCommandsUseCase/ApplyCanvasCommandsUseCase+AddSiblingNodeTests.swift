import Application
import Domain
import Testing

// Background: Sibling creation depends on parent-child links from the focused node.
// Responsibility: Verify sibling creation under the same parent and no-op behavior without a parent.
@Test("ApplyCanvasCommandsUseCase: addSiblingNode creates sibling under same parent")
func test_apply_addSiblingNode_createsSiblingUnderSameParent() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let focusedChildID = CanvasNodeID(rawValue: "focused-child")
    let root = CanvasNode(
        id: rootID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
    )
    let focusedChild = CanvasNode(
        id: focusedChildID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 160, width: 220, height: 120)
    )
    let rootToFocusedChild = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-focused-child"),
        fromNodeID: rootID,
        toNodeID: focusedChildID,
        relationType: .parentChild
    )
    let graph = CanvasGraph(
        nodesByID: [rootID: root, focusedChildID: focusedChild],
        edgesByID: [rootToFocusedChild.id: rootToFocusedChild],
        focusedNodeID: focusedChildID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addSiblingNode])

    #expect(result.newState.nodesByID.count == 3)
    let siblingID = try #require(result.newState.focusedNodeID)
    let sibling = try #require(result.newState.nodesByID[siblingID])
    #expect(sibling.id != rootID)
    #expect(sibling.id != focusedChildID)
    #expect(sibling.bounds.x == focusedChild.bounds.x)
    #expect(sibling.bounds.y == focusedChild.bounds.y + focusedChild.bounds.height + 24)
    let siblingEdge = try #require(
        result.newState.edgesByID.values.first(where: { $0.toNodeID == siblingID })
    )
    #expect(siblingEdge.fromNodeID == rootID)
    #expect(siblingEdge.relationType == .parentChild)
}

@Test("ApplyCanvasCommandsUseCase: addSiblingNode avoids overlap by moving downward")
func test_apply_addSiblingNode_avoidsOverlapByMovingDownward() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let focusedChildID = CanvasNodeID(rawValue: "focused-child")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let root = CanvasNode(
        id: rootID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
    )
    let focusedChild = CanvasNode(
        id: focusedChildID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 120, width: 220, height: 120)
    )
    let blocker = CanvasNode(
        id: blockerID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 250, width: 220, height: 120)
    )
    let rootToFocusedChild = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-focused-child"),
        fromNodeID: rootID,
        toNodeID: focusedChildID,
        relationType: .parentChild
    )
    let graph = CanvasGraph(
        nodesByID: [rootID: root, focusedChildID: focusedChild, blockerID: blocker],
        edgesByID: [rootToFocusedChild.id: rootToFocusedChild],
        focusedNodeID: focusedChildID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addSiblingNode])

    let siblingID = try #require(result.newState.focusedNodeID)
    let sibling = try #require(result.newState.nodesByID[siblingID])
    #expect(sibling.bounds.x == 140)
    #expect(sibling.bounds.y == 394)
}

@Test("ApplyCanvasCommandsUseCase: addSiblingNode is no-op when focused node has no parent")
func test_apply_addSiblingNode_withoutParent_isNoOp() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 10, y: 20, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addSiblingNode])

    #expect(result.newState == graph)
}
