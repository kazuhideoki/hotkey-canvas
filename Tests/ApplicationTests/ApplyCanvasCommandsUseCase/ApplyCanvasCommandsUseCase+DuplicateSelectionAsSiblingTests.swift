import Application
import Domain
import Testing

// Background: Duplicate command in tree mode must clone subtree content from focus/selection.
// Responsibility: Verify duplicate behavior for focused node and deduplicated multi-selection.
@Test("ApplyCanvasCommandsUseCase: duplicateSelectionAsSibling duplicates focused subtree under same parent")
func test_apply_duplicateSelectionAsSibling_duplicatesFocusedSubtree() async throws {
    let fixture = makeDuplicateFocusedSubtreeFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.duplicateSelectionAsSibling])

    #expect(result.newState.nodesByID.count == 5)
    let duplicatedRootID = try #require(result.newState.focusedNodeID)
    let duplicatedRoot = try #require(result.newState.nodesByID[duplicatedRootID])
    #expect(duplicatedRoot.id != fixture.focusedID)
    #expect(duplicatedRoot.text == "focused")
    #expect(duplicatedRoot.attachments == fixture.focusedNode.attachments)
    #expect(duplicatedRoot.metadata == fixture.focusedNode.metadata)
    #expect(duplicatedRoot.markdownStyleEnabled == fixture.focusedNode.markdownStyleEnabled)
    #expect(duplicatedRoot.bounds.width == fixture.focusedNode.bounds.width)
    #expect(duplicatedRoot.bounds.height == fixture.focusedNode.bounds.height)
    #expect(result.newState.selectedNodeIDs == [duplicatedRootID])

    _ = try #require(
        result.newState.edgesByID.values.first { edge in
            edge.relationType == .parentChild
                && edge.fromNodeID == fixture.rootID
                && edge.toNodeID == duplicatedRootID
        }
    )

    let duplicatedChildEdge = try #require(
        result.newState.edgesByID.values.first { edge in
            edge.relationType == .parentChild
                && edge.fromNodeID == duplicatedRootID
        }
    )
    let duplicatedChild = try #require(result.newState.nodesByID[duplicatedChildEdge.toNodeID])
    #expect(duplicatedChild.id != fixture.childID)
    #expect(duplicatedChild.text == "child")
}

@Test("ApplyCanvasCommandsUseCase: duplicateSelectionAsSibling stops recursive clone on cyclic descendants")
func test_apply_duplicateSelectionAsSibling_stopsOnCyclicDescendants() async throws {
    let fixture = makeDuplicateCyclicDescendantFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.duplicateSelectionAsSibling])

    #expect(result.newState.nodesByID.count == fixture.graph.nodesByID.count + 3)
    let duplicatedRootID = try #require(result.newState.focusedNodeID)
    let duplicatedRootChildEdges = result.newState.edgesByID.values.filter { edge in
        edge.relationType == .parentChild
            && edge.fromNodeID == duplicatedRootID
    }
    #expect(duplicatedRootChildEdges.count == 1)
    let duplicatedFirstChildID = try #require(duplicatedRootChildEdges.first?.toNodeID)
    let duplicatedGrandchildEdges = result.newState.edgesByID.values.filter { edge in
        edge.relationType == .parentChild
            && edge.fromNodeID == duplicatedFirstChildID
    }
    #expect(duplicatedGrandchildEdges.count == 1)
    let duplicatedGrandchildID = try #require(duplicatedGrandchildEdges.first?.toNodeID)
    let duplicatedCycleEdges = result.newState.edgesByID.values.filter { edge in
        edge.relationType == .parentChild
            && edge.fromNodeID == duplicatedGrandchildID
    }
    #expect(duplicatedCycleEdges.isEmpty)
}

@Test("ApplyCanvasCommandsUseCase: duplicateSelectionAsSibling ignores descendant when ancestor is selected")
func test_apply_duplicateSelectionAsSibling_ignoresDescendantSelection() async throws {
    let fixture = makeDuplicateAncestorSelectionFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.duplicateSelectionAsSibling])

    #expect(result.newState.nodesByID.count == 5)
    let duplicatedRootIDs = result.newState.selectedNodeIDs
    #expect(duplicatedRootIDs.count == 1)
    let duplicatedRootID = try #require(duplicatedRootIDs.first)
    let duplicatedRoot = try #require(result.newState.nodesByID[duplicatedRootID])
    #expect(duplicatedRoot.text == "parent")
    let duplicatedChildCount = result.newState.edgesByID.values.filter { edge in
        edge.relationType == .parentChild
            && edge.fromNodeID == duplicatedRootID
    }.count
    #expect(duplicatedChildCount == 1)
}

@Test("ApplyCanvasCommandsUseCase: duplicateSelectionAsSibling does not hang when ancestor chain has cycle")
func test_apply_duplicateSelectionAsSibling_doesNotHangOnAncestorCycle() async throws {
    let fixture = makeDuplicateAncestorCycleFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.duplicateSelectionAsSibling])

    #expect(result.newState.nodesByID.count == fixture.graph.nodesByID.count + 1)
    let duplicatedRootID = try #require(result.newState.focusedNodeID)
    let duplicatedRoot = try #require(result.newState.nodesByID[duplicatedRootID])
    #expect(duplicatedRoot.text == "focus")
}

@Test("ApplyCanvasCommandsUseCase: duplicateSelectionAsSibling preserves shared descendant edges")
func test_apply_duplicateSelectionAsSibling_preservesSharedDescendantEdges() async throws {
    let fixture = makeDuplicateSharedDescendantFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.duplicateSelectionAsSibling])

    #expect(result.newState.nodesByID.count == fixture.graph.nodesByID.count + 4)
    let duplicatedRootID = try #require(result.newState.focusedNodeID)
    let duplicatedRootChildren = result.newState.edgesByID.values.filter { edge in
        edge.relationType == .parentChild
            && edge.fromNodeID == duplicatedRootID
    }
    #expect(duplicatedRootChildren.count == 2)
    let duplicatedParentIDs = Set(duplicatedRootChildren.map(\.toNodeID))
    let duplicatedSharedChildIDs = result.newState.edgesByID.values
        .filter { edge in
            edge.relationType == .parentChild
                && duplicatedParentIDs.contains(edge.fromNodeID)
        }
        .map(\.toNodeID)
    let groupedSharedChildIDs = Dictionary(grouping: duplicatedSharedChildIDs, by: { $0 })
    let sharedChildID = try #require(
        groupedSharedChildIDs.first(where: { $0.value.count == 2 })?.key
    )
    #expect(groupedSharedChildIDs[sharedChildID]?.count == 2)
}

private struct DuplicateFocusedSubtreeFixture {
    let rootID: CanvasNodeID
    let childID: CanvasNodeID
    let focusedID: CanvasNodeID
    let focusedNode: CanvasNode
    let graph: CanvasGraph
}

private func makeDuplicateFocusedSubtreeFixture() -> DuplicateFocusedSubtreeFixture {
    let rootID = CanvasNodeID(rawValue: "root")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let childID = CanvasNodeID(rawValue: "child")
    let rootNode = CanvasNode(
        id: rootID,
        kind: .text,
        text: "root",
        bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
    )
    let focusedNode = CanvasNode(
        id: focusedID,
        kind: .text,
        text: "focused",
        attachments: [
            CanvasAttachment(
                id: CanvasAttachmentID(rawValue: "att-focused"),
                kind: .image(filePath: "/tmp/focused.png"),
                placement: .aboveText
            )
        ],
        bounds: CanvasBounds(x: 260, y: 200, width: 360, height: 160),
        metadata: ["tag": "focused"],
        markdownStyleEnabled: false
    )
    let childNode = CanvasNode(
        id: childID,
        kind: .text,
        text: "child",
        bounds: CanvasBounds(x: 520, y: 200, width: 220, height: 120)
    )
    return DuplicateFocusedSubtreeFixture(
        rootID: rootID,
        childID: childID,
        focusedID: focusedID,
        focusedNode: focusedNode,
        graph: CanvasGraph(
            nodesByID: [rootID: rootNode, focusedID: focusedNode, childID: childNode],
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
                    toNodeID: childID,
                    relationType: .parentChild
                ),
            ],
            focusedNodeID: focusedID
        )
    )
}

private struct DuplicateCyclicDescendantFixture {
    let graph: CanvasGraph
}

private func makeDuplicateCyclicDescendantFixture() -> DuplicateCyclicDescendantFixture {
    let rootID = CanvasNodeID(rawValue: "root")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let childID = CanvasNodeID(rawValue: "child")
    let grandchildID = CanvasNodeID(rawValue: "grandchild")

    return DuplicateCyclicDescendantFixture(
        graph: CanvasGraph(
            nodesByID: [
                rootID: makeTextNode(id: rootID, text: "root", x: 0, y: 0),
                focusedID: makeTextNode(id: focusedID, text: "focused", x: 260, y: 160),
                childID: makeTextNode(id: childID, text: "child", x: 520, y: 160),
                grandchildID: makeTextNode(id: grandchildID, text: "grandchild", x: 780, y: 160),
            ],
            edgesByID: Dictionary(uniqueKeysWithValues: [
                makeParentChildEdge(id: "edge-root-focused", from: rootID, to: focusedID),
                makeParentChildEdge(id: "edge-focused-child", from: focusedID, to: childID),
                makeParentChildEdge(id: "edge-child-grandchild", from: childID, to: grandchildID),
                makeParentChildEdge(id: "edge-grandchild-child", from: grandchildID, to: childID),
            ]),
            focusedNodeID: focusedID
        )
    )
}

private struct DuplicateAncestorCycleFixture {
    let graph: CanvasGraph
}

private func makeDuplicateAncestorCycleFixture() -> DuplicateAncestorCycleFixture {
    let parentAID = CanvasNodeID(rawValue: "parent-a")
    let parentBID = CanvasNodeID(rawValue: "parent-b")
    let focusID = CanvasNodeID(rawValue: "focus")

    return DuplicateAncestorCycleFixture(
        graph: CanvasGraph(
            nodesByID: [
                parentAID: makeTextNode(id: parentAID, text: "parent-a", x: 0, y: 0),
                parentBID: makeTextNode(id: parentBID, text: "parent-b", x: 260, y: 0),
                focusID: makeTextNode(id: focusID, text: "focus", x: 520, y: 0),
            ],
            edgesByID: Dictionary(uniqueKeysWithValues: [
                makeParentChildEdge(id: "edge-a-b", from: parentAID, to: parentBID),
                makeParentChildEdge(id: "edge-b-a", from: parentBID, to: parentAID),
                makeParentChildEdge(id: "edge-a-focus", from: parentAID, to: focusID),
            ]),
            focusedNodeID: focusID
        )
    )
}

private struct DuplicateSharedDescendantFixture {
    let graph: CanvasGraph
}

private func makeDuplicateSharedDescendantFixture() -> DuplicateSharedDescendantFixture {
    let parentID = CanvasNodeID(rawValue: "parent")
    let rootID = CanvasNodeID(rawValue: "root")
    let leftID = CanvasNodeID(rawValue: "left")
    let rightID = CanvasNodeID(rawValue: "right")
    let sharedChildID = CanvasNodeID(rawValue: "shared")

    return DuplicateSharedDescendantFixture(
        graph: CanvasGraph(
            nodesByID: [
                parentID: makeTextNode(id: parentID, text: "parent", x: -260, y: 0),
                rootID: makeTextNode(id: rootID, text: "root", x: 0, y: 0),
                leftID: makeTextNode(id: leftID, text: "left", x: 260, y: 0),
                rightID: makeTextNode(id: rightID, text: "right", x: 260, y: 160),
                sharedChildID: makeTextNode(id: sharedChildID, text: "shared", x: 520, y: 80),
            ],
            edgesByID: Dictionary(uniqueKeysWithValues: [
                makeParentChildEdge(id: "edge-parent-root", from: parentID, to: rootID),
                makeParentChildEdge(id: "edge-root-left", from: rootID, to: leftID),
                makeParentChildEdge(id: "edge-root-right", from: rootID, to: rightID),
                makeParentChildEdge(id: "edge-left-shared", from: leftID, to: sharedChildID),
                makeParentChildEdge(id: "edge-right-shared", from: rightID, to: sharedChildID),
            ]),
            focusedNodeID: rootID
        )
    )
}

private func makeTextNode(
    id: CanvasNodeID,
    text: String,
    x: Double,
    y: Double
) -> CanvasNode {
    CanvasNode(
        id: id,
        kind: .text,
        text: text,
        bounds: CanvasBounds(x: x, y: y, width: 220, height: 120)
    )
}

private func makeParentChildEdge(
    id: String,
    from fromNodeID: CanvasNodeID,
    to toNodeID: CanvasNodeID
) -> (CanvasEdgeID, CanvasEdge) {
    let edgeID = CanvasEdgeID(rawValue: id)
    return (
        edgeID,
        CanvasEdge(
            id: edgeID,
            fromNodeID: fromNodeID,
            toNodeID: toNodeID,
            relationType: .parentChild
        )
    )
}

private struct DuplicateAncestorSelectionFixture {
    let graph: CanvasGraph
}

private func makeDuplicateAncestorSelectionFixture() -> DuplicateAncestorSelectionFixture {
    let rootID = CanvasNodeID(rawValue: "root")
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let rootNode = CanvasNode(
        id: rootID,
        kind: .text,
        text: "root",
        bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
    )
    let parentNode = CanvasNode(
        id: parentID,
        kind: .text,
        text: "parent",
        bounds: CanvasBounds(x: 260, y: 140, width: 220, height: 120)
    )
    let childNode = CanvasNode(
        id: childID,
        kind: .text,
        text: "child",
        bounds: CanvasBounds(x: 520, y: 140, width: 220, height: 120)
    )
    return DuplicateAncestorSelectionFixture(
        graph: CanvasGraph(
            nodesByID: [rootID: rootNode, parentID: parentNode, childID: childNode],
            edgesByID: [
                CanvasEdgeID(rawValue: "edge-root-parent"): CanvasEdge(
                    id: CanvasEdgeID(rawValue: "edge-root-parent"),
                    fromNodeID: rootID,
                    toNodeID: parentID,
                    relationType: .parentChild
                ),
                CanvasEdgeID(rawValue: "edge-parent-child"): CanvasEdge(
                    id: CanvasEdgeID(rawValue: "edge-parent-child"),
                    fromNodeID: parentID,
                    toNodeID: childID,
                    relationType: .parentChild
                ),
            ],
            focusedNodeID: parentID,
            selectedNodeIDs: [parentID, childID]
        )
    )
}
