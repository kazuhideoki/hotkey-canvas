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
    let updatedRoot = try #require(result.newState.nodesByID[rootID])
    let updatedFocusedChild = try #require(result.newState.nodesByID[focusedChildID])
    #expect(sibling.id != rootID)
    #expect(sibling.id != focusedChildID)
    #expect(updatedFocusedChild.bounds.x == updatedRoot.bounds.x + updatedRoot.bounds.width + 32)
    #expect(sibling.bounds.x == updatedFocusedChild.bounds.x)
    #expect(sibling.bounds.y >= updatedFocusedChild.bounds.y + updatedFocusedChild.bounds.height + 24)
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

    #expect(updatedRoot.bounds == root.bounds)
    #expect(updatedFocusedChild.bounds.x == updatedRoot.bounds.x + updatedRoot.bounds.width + 32)
    #expect(sibling.bounds.x == updatedFocusedChild.bounds.x)
    #expect(sibling.bounds.y >= updatedFocusedChild.bounds.y + updatedFocusedChild.bounds.height + 24)

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
    let updatedRoot = try #require(result.newState.nodesByID[rootID])
    let updatedFocusedChild = try #require(result.newState.nodesByID[focusedChildID])
    #expect(updatedFocusedChild.bounds.x == updatedRoot.bounds.x + updatedRoot.bounds.width + 32)
    #expect(sibling.bounds.x == updatedFocusedChild.bounds.x)
    #expect(sibling.bounds.y + sibling.bounds.height + 24 <= updatedFocusedChild.bounds.y)
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
    let focusedAfter = try #require(result.newState.nodesByID[focusedChildID])
    let lowerSiblingAfter = try #require(result.newState.nodesByID[lowerSiblingID])
    #expect(newSibling.id != lowerSiblingID)
    #expect(boundsOverlap(newSibling.bounds, lowerSiblingAfter.bounds, spacing: 0) == false)
    #expect(newSibling.bounds.x == lowerSiblingAfter.bounds.x)
    #expect(newSibling.bounds.y >= focusedAfter.bounds.y + focusedAfter.bounds.height + 24)
    #expect(newSibling.bounds.y + newSibling.bounds.height + 24 <= lowerSiblingAfter.bounds.y)
}

@Test("ApplyCanvasCommandsUseCase: addSiblingNode above inserts between previous sibling and focused node")
func test_apply_addSiblingNodeAbove_insertsBetweenPreviousAndFocusedSibling() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let upperSiblingID = CanvasNodeID(rawValue: "upper")
    let focusedChildID = CanvasNodeID(rawValue: "focused")
    let lowerSiblingID = CanvasNodeID(rawValue: "lower")

    let root = CanvasNode(
        id: rootID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
    )
    let upperSibling = CanvasNode(
        id: upperSiblingID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 40, width: 220, height: 120)
    )
    let focusedChild = CanvasNode(
        id: focusedChildID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 220, width: 220, height: 120)
    )
    let lowerSibling = CanvasNode(
        id: lowerSiblingID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 420, width: 220, height: 120)
    )
    let edgeUpper = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-upper"),
        fromNodeID: rootID,
        toNodeID: upperSiblingID,
        relationType: .parentChild
    )
    let edgeFocused = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-focused"),
        fromNodeID: rootID,
        toNodeID: focusedChildID,
        relationType: .parentChild
    )
    let edgeLower = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-lower"),
        fromNodeID: rootID,
        toNodeID: lowerSiblingID,
        relationType: .parentChild
    )
    let graph = CanvasGraph(
        nodesByID: [
            rootID: root,
            upperSiblingID: upperSibling,
            focusedChildID: focusedChild,
            lowerSiblingID: lowerSibling,
        ],
        edgesByID: [
            edgeUpper.id: edgeUpper,
            edgeFocused.id: edgeFocused,
            edgeLower.id: edgeLower,
        ],
        focusedNodeID: focusedChildID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addSiblingNode(position: .above)])

    let newSiblingID = try #require(result.newState.focusedNodeID)
    let children = result.newState.edgesByID.values
        .filter { $0.relationType == .parentChild && $0.fromNodeID == rootID }
        .compactMap { result.newState.nodesByID[$0.toNodeID] }
        .sorted {
            if $0.bounds.y == $1.bounds.y {
                if $0.bounds.x == $1.bounds.x {
                    return $0.id.rawValue < $1.id.rawValue
                }
                return $0.bounds.x < $1.bounds.x
            }
            return $0.bounds.y < $1.bounds.y
        }
    let newIndex = try #require(children.firstIndex(where: { $0.id == newSiblingID }))
    let focusedIndex = try #require(children.firstIndex(where: { $0.id == focusedChildID }))
    let upperIndex = try #require(children.firstIndex(where: { $0.id == upperSiblingID }))

    #expect(children.count == 4)
    #expect(upperIndex < newIndex)
    #expect(newIndex < focusedIndex)
}

@Test("ApplyCanvasCommandsUseCase: addSiblingNode above keeps ordering when previous sibling shares Y")
func test_apply_addSiblingNodeAbove_withEqualY_keepsNewNodeAboveFocused() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let previousID = CanvasNodeID(rawValue: "previous")
    let focusedID = CanvasNodeID(rawValue: "focused")

    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            ),
            previousID: CanvasNode(
                id: previousID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 120, y: 200, width: 220, height: 120)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 200, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-previous"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-previous"),
                fromNodeID: rootID,
                toNodeID: previousID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-focused"),
                fromNodeID: rootID,
                toNodeID: focusedID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addSiblingNode(position: .above)])

    let newSiblingID = try #require(result.newState.focusedNodeID)
    let children = result.newState.edgesByID.values
        .filter { $0.relationType == .parentChild && $0.fromNodeID == rootID }
        .compactMap { result.newState.nodesByID[$0.toNodeID] }
        .sorted {
            if $0.bounds.y == $1.bounds.y {
                if $0.bounds.x == $1.bounds.x {
                    return $0.id.rawValue < $1.id.rawValue
                }
                return $0.bounds.x < $1.bounds.x
            }
            return $0.bounds.y < $1.bounds.y
        }
    let newIndex = try #require(children.firstIndex(where: { $0.id == newSiblingID }))
    let focusedIndex = try #require(children.firstIndex(where: { $0.id == focusedID }))
    #expect(newIndex < focusedIndex)
}

@Test("ApplyCanvasCommandsUseCase: addSiblingNode below keeps ordering when next sibling shares Y")
func test_apply_addSiblingNodeBelow_withEqualY_keepsNewNodeBelowFocused() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let nextID = CanvasNodeID(rawValue: "next")

    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 120, y: 200, width: 220, height: 120)
            ),
            nextID: CanvasNode(
                id: nextID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 200, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-focused"),
                fromNodeID: rootID,
                toNodeID: focusedID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-next"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-next"),
                fromNodeID: rootID,
                toNodeID: nextID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addSiblingNode(position: .below)])

    let newSiblingID = try #require(result.newState.focusedNodeID)
    let children = result.newState.edgesByID.values
        .filter { $0.relationType == .parentChild && $0.fromNodeID == rootID }
        .compactMap { result.newState.nodesByID[$0.toNodeID] }
        .sorted {
            if $0.bounds.y == $1.bounds.y {
                if $0.bounds.x == $1.bounds.x {
                    return $0.id.rawValue < $1.id.rawValue
                }
                return $0.bounds.x < $1.bounds.x
            }
            return $0.bounds.y < $1.bounds.y
        }
    let newIndex = try #require(children.firstIndex(where: { $0.id == newSiblingID }))
    let focusedIndex = try #require(children.firstIndex(where: { $0.id == focusedID }))
    #expect(newIndex > focusedIndex)
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
