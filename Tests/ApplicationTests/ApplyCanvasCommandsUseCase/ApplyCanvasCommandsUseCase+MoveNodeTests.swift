import Application
import Domain
import Testing

// Background: Command-arrow shortcuts modify node hierarchy and sibling order.
// Responsibility: Verify moveNode command behavior for up/down/left/right transitions.
@Test("ApplyCanvasCommandsUseCase: moveNode down swaps with next sibling")
func test_apply_moveNodeDown_swapsWithNextSibling() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let firstID = CanvasNodeID(rawValue: "first")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let thirdID = CanvasNodeID(rawValue: "third")
    let graph = makeSiblingGraph(rootID: rootID, childIDs: [firstID, focusedID, thirdID], focusedID: focusedID)
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.down)])
    let sortedChildIDs = childNodeIDs(of: rootID, in: result.newState)

    #expect(sortedChildIDs == [firstID, thirdID, focusedID])
    #expect(result.newState.focusedNodeID == focusedID)
}

@Test("ApplyCanvasCommandsUseCase: moveNode down preserves each node size")
func test_apply_moveNodeDown_preservesNodeSize() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let nextID = CanvasNodeID(rawValue: "next")

    let root = CanvasNode(
        id: rootID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
    )
    let focused = CanvasNode(
        id: focusedID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 260, y: 0, width: 300, height: 80)
    )
    let next = CanvasNode(
        id: nextID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 260, y: 200, width: 180, height: 160)
    )
    let edgeFocused = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-focused"),
        fromNodeID: rootID,
        toNodeID: focusedID,
        relationType: .parentChild
    )
    let edgeNext = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-next"),
        fromNodeID: rootID,
        toNodeID: nextID,
        relationType: .parentChild
    )
    let graph = CanvasGraph(
        nodesByID: [rootID: root, focusedID: focused, nextID: next],
        edgesByID: [edgeFocused.id: edgeFocused, edgeNext.id: edgeNext],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.down)])

    let focusedAfter = try #require(result.newState.nodesByID[focusedID])
    let nextAfter = try #require(result.newState.nodesByID[nextID])
    #expect(focusedAfter.bounds.width == focused.bounds.width)
    #expect(focusedAfter.bounds.height == focused.bounds.height)
    #expect(nextAfter.bounds.width == next.bounds.width)
    #expect(nextAfter.bounds.height == next.bounds.height)
}

@Test("ApplyCanvasCommandsUseCase: moveNode up swaps with previous sibling")
func test_apply_moveNodeUp_swapsWithPreviousSibling() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let firstID = CanvasNodeID(rawValue: "first")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let thirdID = CanvasNodeID(rawValue: "third")
    let graph = makeSiblingGraph(rootID: rootID, childIDs: [firstID, focusedID, thirdID], focusedID: focusedID)
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.up)])
    let sortedChildIDs = childNodeIDs(of: rootID, in: result.newState)

    #expect(sortedChildIDs == [focusedID, firstID, thirdID])
    #expect(result.newState.focusedNodeID == focusedID)
}

@Test("ApplyCanvasCommandsUseCase: moveNode left promotes node to parent sibling")
func test_apply_moveNodeLeft_promotesToParentSibling() async throws {
    let grandID = CanvasNodeID(rawValue: "grand")
    let parentID = CanvasNodeID(rawValue: "parent")
    let focusedID = CanvasNodeID(rawValue: "focused")

    let grand = CanvasNode(
        id: grandID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
    )
    let parent = CanvasNode(
        id: parentID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 260, y: 0, width: 220, height: 120)
    )
    let focused = CanvasNode(
        id: focusedID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 520, y: 0, width: 220, height: 120)
    )
    let edgeGrandToParent = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-grand-parent"),
        fromNodeID: grandID,
        toNodeID: parentID,
        relationType: .parentChild
    )
    let edgeParentToFocused = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-parent-focused"),
        fromNodeID: parentID,
        toNodeID: focusedID,
        relationType: .parentChild
    )
    let graph = CanvasGraph(
        nodesByID: [grandID: grand, parentID: parent, focusedID: focused],
        edgesByID: [edgeGrandToParent.id: edgeGrandToParent, edgeParentToFocused.id: edgeParentToFocused],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.left)])

    #expect(hasParentChildEdge(from: parentID, to: focusedID, in: result.newState) == false)
    #expect(hasParentChildEdge(from: grandID, to: focusedID, in: result.newState))
    #expect(result.newState.focusedNodeID == focusedID)
}

@Test("ApplyCanvasCommandsUseCase: moveNode right indents node under previous sibling")
func test_apply_moveNodeRight_indentsUnderPreviousSibling() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let previousID = CanvasNodeID(rawValue: "previous")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let graph = makeSiblingGraph(rootID: rootID, childIDs: [previousID, focusedID], focusedID: focusedID)
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.right)])

    #expect(hasParentChildEdge(from: rootID, to: focusedID, in: result.newState) == false)
    #expect(hasParentChildEdge(from: previousID, to: focusedID, in: result.newState))
    #expect(result.newState.focusedNodeID == focusedID)
}

private func makeSiblingGraph(
    rootID: CanvasNodeID,
    childIDs: [CanvasNodeID],
    focusedID: CanvasNodeID
) -> CanvasGraph {
    var nodesByID: [CanvasNodeID: CanvasNode] = [
        rootID: CanvasNode(
            id: rootID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
        )
    ]
    var edgesByID: [CanvasEdgeID: CanvasEdge] = [:]

    for (index, childID) in childIDs.enumerated() {
        let child = CanvasNode(
            id: childID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(
                x: 260,
                y: Double(index) * 200,
                width: 220,
                height: 120
            )
        )
        nodesByID[childID] = child
        let edgeID = CanvasEdgeID(rawValue: "edge-\(rootID.rawValue)-\(childID.rawValue)")
        edgesByID[edgeID] = CanvasEdge(
            id: edgeID,
            fromNodeID: rootID,
            toNodeID: childID,
            relationType: .parentChild
        )
    }

    return CanvasGraph(nodesByID: nodesByID, edgesByID: edgesByID, focusedNodeID: focusedID)
}

private func childNodeIDs(of parentID: CanvasNodeID, in graph: CanvasGraph) -> [CanvasNodeID] {
    graph.edgesByID.values
        .filter { $0.relationType == .parentChild && $0.fromNodeID == parentID }
        .compactMap { graph.nodesByID[$0.toNodeID] }
        .sorted {
            if $0.bounds.y == $1.bounds.y {
                if $0.bounds.x == $1.bounds.x {
                    return $0.id.rawValue < $1.id.rawValue
                }
                return $0.bounds.x < $1.bounds.x
            }
            return $0.bounds.y < $1.bounds.y
        }
        .map(\.id)
}

private func hasParentChildEdge(from parentID: CanvasNodeID, to childID: CanvasNodeID, in graph: CanvasGraph) -> Bool {
    graph.edgesByID.values.contains {
        $0.relationType == .parentChild
            && $0.fromNodeID == parentID
            && $0.toNodeID == childID
    }
}
