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

    let result = try await sut.apply(commands: [.addSiblingNode(position: .below)])

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

@Test("ApplyCanvasCommandsUseCase: addSiblingNode resolves overlap by moving areas")
func test_apply_addSiblingNode_resolvesOverlapByMovingAreas() async throws {
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

    let result = try await sut.apply(commands: [.addSiblingNode(position: .below)])

    let siblingID = try #require(result.newState.focusedNodeID)
    let sibling = try #require(result.newState.nodesByID[siblingID])
    let updatedRoot = try #require(result.newState.nodesByID[rootID])
    let updatedFocusedChild = try #require(result.newState.nodesByID[focusedChildID])
    let updatedBlocker = try #require(result.newState.nodesByID[blockerID])

    #expect(updatedRoot.bounds.x != root.bounds.x || updatedRoot.bounds.y != root.bounds.y)
    #expect(updatedBlocker.bounds.x != blocker.bounds.x || updatedBlocker.bounds.y != blocker.bounds.y)
    #expect(updatedFocusedChild.bounds.x - updatedRoot.bounds.x == focusedChild.bounds.x - root.bounds.x)
    #expect(updatedFocusedChild.bounds.y - updatedRoot.bounds.y == focusedChild.bounds.y - root.bounds.y)
    #expect(sibling.bounds.x - updatedRoot.bounds.x == 140)
    #expect(sibling.bounds.y - updatedRoot.bounds.y == 264)

    let siblingAreaBounds = enclosingBounds(of: [updatedRoot, updatedFocusedChild, sibling])
    #expect(boundsOverlap(siblingAreaBounds, updatedBlocker.bounds, spacing: 32) == false)
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

    let result = try await sut.apply(commands: [.addSiblingNode(position: .below)])

    #expect(result.newState == graph)
}

@Test("ApplyCanvasCommandsUseCase: addSiblingNode above places node directly above focused node")
func test_apply_addSiblingNodeAbove_placesNodeAboveFocusedNode() async throws {
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
        bounds: CanvasBounds(x: 80, y: 200, width: 220, height: 120)
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

    let result = try await sut.apply(commands: [.addSiblingNode(position: .above)])

    let siblingID = try #require(result.newState.focusedNodeID)
    let sibling = try #require(result.newState.nodesByID[siblingID])
    #expect(sibling.bounds.x == focusedChild.bounds.x)
    #expect(sibling.bounds.y == focusedChild.bounds.y - sibling.bounds.height - 24)
}

@Test("ApplyCanvasCommandsUseCase: addSiblingNode avoids occupied slot within same parent area")
func test_apply_addSiblingNode_avoidsOccupiedSlotWithinSameArea() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let focusedChildID = CanvasNodeID(rawValue: "focused-child")
    let lowerSiblingID = CanvasNodeID(rawValue: "lower-sibling")
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
    let lowerSibling = CanvasNode(
        id: lowerSiblingID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 264, width: 220, height: 120)
    )
    let rootToFocused = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-focused"),
        fromNodeID: rootID,
        toNodeID: focusedChildID,
        relationType: .parentChild
    )
    let rootToLower = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-lower"),
        fromNodeID: rootID,
        toNodeID: lowerSiblingID,
        relationType: .parentChild
    )
    let graph = CanvasGraph(
        nodesByID: [rootID: root, focusedChildID: focusedChild, lowerSiblingID: lowerSibling],
        edgesByID: [rootToFocused.id: rootToFocused, rootToLower.id: rootToLower],
        focusedNodeID: focusedChildID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addSiblingNode(position: .below)])

    let siblingID = try #require(result.newState.focusedNodeID)
    let newSibling = try #require(result.newState.nodesByID[siblingID])
    let lowerSiblingAfter = try #require(result.newState.nodesByID[lowerSiblingID])
    #expect(newSibling.id != lowerSiblingID)
    #expect(boundsOverlap(newSibling.bounds, lowerSiblingAfter.bounds, spacing: 0) == false)
    #expect(newSibling.bounds.x == lowerSiblingAfter.bounds.x)
    #expect(newSibling.bounds.y == lowerSiblingAfter.bounds.y + lowerSiblingAfter.bounds.height + 24)
}

private func enclosingBounds(of nodes: [CanvasNode]) -> CanvasBounds {
    guard let first = nodes.first else {
        return CanvasBounds(x: 0, y: 0, width: 0, height: 0)
    }

    var minX = first.bounds.x
    var minY = first.bounds.y
    var maxX = first.bounds.x + first.bounds.width
    var maxY = first.bounds.y + first.bounds.height

    for node in nodes.dropFirst() {
        minX = min(minX, node.bounds.x)
        minY = min(minY, node.bounds.y)
        maxX = max(maxX, node.bounds.x + node.bounds.width)
        maxY = max(maxY, node.bounds.y + node.bounds.height)
    }

    return CanvasBounds(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
