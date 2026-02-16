import Application
import Domain
import Testing

// Background: Sibling creation depends on parent-child links from the focused node.
// Responsibility: Verify sibling creation under the same parent and no-op behavior without a parent.
private struct AddSiblingInsertionFixture {
    let graph: CanvasGraph
    let rootID: CanvasNodeID
    let upperSiblingID: CanvasNodeID
    let focusedChildID: CanvasNodeID
}

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

    let siblingAreaBounds = addSiblingTestEnclosingBounds(of: [updatedRoot, updatedFocusedChild, sibling])
    #expect(addSiblingTestBoundsOverlap(siblingAreaBounds, updatedBlocker.bounds, spacing: 32) == false)
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
    #expect(addSiblingTestBoundsOverlap(newSibling.bounds, lowerSiblingAfter.bounds, spacing: 0) == false)
    #expect(newSibling.bounds.x == lowerSiblingAfter.bounds.x)
    #expect(newSibling.bounds.y >= focusedAfter.bounds.y + focusedAfter.bounds.height + 24)
    #expect(newSibling.bounds.y + newSibling.bounds.height + 24 <= lowerSiblingAfter.bounds.y)
}

@Test("ApplyCanvasCommandsUseCase: addSiblingNode above inserts between previous sibling and focused node")
func test_apply_addSiblingNodeAbove_insertsBetweenPreviousAndFocusedSibling() async throws {
    let fixture = makeAddSiblingInsertionFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    let result = try await sut.apply(commands: [.addSiblingNode(position: .above)])

    let newSiblingID = try #require(result.newState.focusedNodeID)
    let children = result.newState.edgesByID.values
        .filter { $0.relationType == .parentChild && $0.fromNodeID == fixture.rootID }
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
    let focusedIndex = try #require(children.firstIndex(where: { $0.id == fixture.focusedChildID }))
    let upperIndex = try #require(children.firstIndex(where: { $0.id == fixture.upperSiblingID }))

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

private func makeAddSiblingInsertionFixture() -> AddSiblingInsertionFixture {
    let rootID = CanvasNodeID(rawValue: "root")
    let upperSiblingID = CanvasNodeID(rawValue: "upper")
    let focusedChildID = CanvasNodeID(rawValue: "focused")
    let lowerSiblingID = CanvasNodeID(rawValue: "lower")

    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            ),
            upperSiblingID: CanvasNode(
                id: upperSiblingID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 140, y: 40, width: 220, height: 120)
            ),
            focusedChildID: CanvasNode(
                id: focusedChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 140, y: 220, width: 220, height: 120)
            ),
            lowerSiblingID: CanvasNode(
                id: lowerSiblingID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 140, y: 420, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-upper"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-upper"),
                fromNodeID: rootID,
                toNodeID: upperSiblingID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-focused"),
                fromNodeID: rootID,
                toNodeID: focusedChildID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-lower"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-lower"),
                fromNodeID: rootID,
                toNodeID: lowerSiblingID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedChildID
    )
    return AddSiblingInsertionFixture(
        graph: graph,
        rootID: rootID,
        upperSiblingID: upperSiblingID,
        focusedChildID: focusedChildID
    )
}
