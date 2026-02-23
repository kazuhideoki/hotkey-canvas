import Application
import Domain
import Testing

// Background: Tree move should support multi-selection while preserving focus-driven command semantics.
// Responsibility: Verify multi-selection moveNode behavior in tree mode.
@Test("ApplyCanvasCommandsUseCase: moveNode down moves multi-selection as siblings under focused destination parent")
func test_apply_moveNodeDown_multiSelectionAcrossParents_becomesSiblingsAtDestination() async throws {
    let fixture = makeMoveNodeDownMultiSelectionFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveNode(.down)])

    #expect(multiSelectionParentNodeID(of: fixture.focusedID, in: result.newState) == fixture.parentAID)
    #expect(multiSelectionParentNodeID(of: fixture.selectedID, in: result.newState) == fixture.parentAID)
    #expect(
        multiSelectionChildNodeIDs(of: fixture.parentAID, in: result.newState) == [
            fixture.lowerSiblingID, fixture.focusedID, fixture.selectedID,
        ])
    #expect(result.newState.focusedNodeID == fixture.focusedID)
    #expect(result.newState.selectedNodeIDs == [fixture.focusedID, fixture.selectedID])
}

@Test("ApplyCanvasCommandsUseCase: moveNode down swaps sibling block when multi-selection is adjacent")
func test_apply_moveNodeDown_multiSelectionSiblings_swapsAsBlock() async throws {
    let fixture = makeMoveNodeSiblingBlockMultiSelectionFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveNode(.down)])

    #expect(
        multiSelectionChildNodeIDs(of: fixture.rootID, in: result.newState) == [
            fixture.topID, fixture.bottomID, fixture.focusedID, fixture.selectedID,
        ]
    )
}

@Test("ApplyCanvasCommandsUseCase: moveNode up swaps sibling block when multi-selection is adjacent")
func test_apply_moveNodeUp_multiSelectionSiblings_swapsAsBlock() async throws {
    let fixture = makeMoveNodeSiblingBlockMultiSelectionFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveNode(.up)])

    #expect(
        multiSelectionChildNodeIDs(of: fixture.rootID, in: result.newState) == [
            fixture.focusedID, fixture.selectedID, fixture.topID, fixture.bottomID,
        ]
    )
}

@Test("ApplyCanvasCommandsUseCase: moveNode right flattens selected parent-child relation into siblings")
func test_apply_moveNodeRight_multiSelectionWithNestedNodes_flattensToSiblings() async throws {
    let fixture = makeMoveNodeRightMultiSelectionFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveNode(.right)])

    #expect(multiSelectionParentNodeID(of: fixture.focusedID, in: result.newState) == fixture.previousID)
    #expect(multiSelectionParentNodeID(of: fixture.selectedChildID, in: result.newState) == fixture.previousID)
    #expect(
        multiSelectionHasParentChildEdge(
            from: fixture.focusedID,
            to: fixture.selectedChildID,
            in: result.newState
        ) == false
    )
}

@Test("ApplyCanvasCommandsUseCase: moveNode right keeps collapsed destination parent focus in multi-selection")
func test_apply_moveNodeRight_multiSelectionKeepsCollapsedDestinationParentFocus() async throws {
    let fixture = makeMoveNodeRightCollapsedFocusMultiSelectionFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveNode(.right)])

    #expect(result.newState.focusedNodeID == fixture.previousID)
    #expect(multiSelectionParentNodeID(of: fixture.focusedID, in: result.newState) == fixture.previousID)
    #expect(multiSelectionParentNodeID(of: fixture.selectedChildID, in: result.newState) == fixture.previousID)
}

private struct MoveNodeDownMultiSelectionFixture {
    let graph: CanvasGraph
    let parentAID: CanvasNodeID
    let focusedID: CanvasNodeID
    let selectedID: CanvasNodeID
    let lowerSiblingID: CanvasNodeID
}

private struct MoveNodeSiblingBlockMultiSelectionFixture {
    let graph: CanvasGraph
    let rootID: CanvasNodeID
    let topID: CanvasNodeID
    let focusedID: CanvasNodeID
    let selectedID: CanvasNodeID
    let bottomID: CanvasNodeID
}

private func makeMoveNodeSiblingBlockMultiSelectionFixture() -> MoveNodeSiblingBlockMultiSelectionFixture {
    let rootID = CanvasNodeID(rawValue: "root-sibling-block")
    let topID = CanvasNodeID(rawValue: "top-sibling-block")
    let focusedID = CanvasNodeID(rawValue: "focused-sibling-block")
    let selectedID = CanvasNodeID(rawValue: "selected-sibling-block")
    let bottomID = CanvasNodeID(rawValue: "bottom-sibling-block")

    let graph = makeMoveNodeSiblingBlockGraph(
        rootID: rootID,
        topID: topID,
        focusedID: focusedID,
        selectedID: selectedID,
        bottomID: bottomID
    )

    return MoveNodeSiblingBlockMultiSelectionFixture(
        graph: graph,
        rootID: rootID,
        topID: topID,
        focusedID: focusedID,
        selectedID: selectedID,
        bottomID: bottomID
    )
}

private func makeMoveNodeSiblingBlockGraph(
    rootID: CanvasNodeID,
    topID: CanvasNodeID,
    focusedID: CanvasNodeID,
    selectedID: CanvasNodeID,
    bottomID: CanvasNodeID
) -> CanvasGraph {
    CanvasGraph(
        nodesByID: makeMoveNodeSiblingBlockNodes(
            rootID: rootID,
            topID: topID,
            focusedID: focusedID,
            selectedID: selectedID,
            bottomID: bottomID
        ),
        edgesByID: makeMoveNodeSiblingBlockEdges(
            rootID: rootID,
            topID: topID,
            focusedID: focusedID,
            selectedID: selectedID,
            bottomID: bottomID
        ),
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID]
    )
}

private func makeMoveNodeSiblingBlockNodes(
    rootID: CanvasNodeID,
    topID: CanvasNodeID,
    focusedID: CanvasNodeID,
    selectedID: CanvasNodeID,
    bottomID: CanvasNodeID
) -> [CanvasNodeID: CanvasNode] {
    [
        rootID: CanvasNode(
            id: rootID, kind: .text, text: nil, bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)),
        topID: CanvasNode(
            id: topID, kind: .text, text: nil, bounds: CanvasBounds(x: 260, y: 0, width: 220, height: 120)),
        focusedID: CanvasNode(
            id: focusedID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 260, y: 140, width: 220, height: 120)
        ),
        selectedID: CanvasNode(
            id: selectedID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 260, y: 280, width: 220, height: 120)
        ),
        bottomID: CanvasNode(
            id: bottomID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 260, y: 420, width: 220, height: 120)
        ),
    ]
}

private func makeMoveNodeSiblingBlockEdges(
    rootID: CanvasNodeID,
    topID: CanvasNodeID,
    focusedID: CanvasNodeID,
    selectedID: CanvasNodeID,
    bottomID: CanvasNodeID
) -> [CanvasEdgeID: CanvasEdge] {
    [
        CanvasEdgeID(rawValue: "edge-root-top-sibling-block"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-root-top-sibling-block"),
            fromNodeID: rootID,
            toNodeID: topID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-root-focused-sibling-block"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-root-focused-sibling-block"),
            fromNodeID: rootID,
            toNodeID: focusedID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-root-selected-sibling-block"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-root-selected-sibling-block"),
            fromNodeID: rootID,
            toNodeID: selectedID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-root-bottom-sibling-block"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-root-bottom-sibling-block"),
            fromNodeID: rootID,
            toNodeID: bottomID,
            relationType: .parentChild
        ),
    ]
}

private func makeMoveNodeDownMultiSelectionFixture() -> MoveNodeDownMultiSelectionFixture {
    let parentAID = CanvasNodeID(rawValue: "parent-a")
    let parentBID = CanvasNodeID(rawValue: "parent-b")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let selectedID = CanvasNodeID(rawValue: "selected")
    let lowerSiblingID = CanvasNodeID(rawValue: "lower")

    let graph = CanvasGraph(
        nodesByID: makeMoveNodeDownMultiSelectionNodes(
            parentAID: parentAID,
            parentBID: parentBID,
            focusedID: focusedID,
            selectedID: selectedID,
            lowerSiblingID: lowerSiblingID
        ),
        edgesByID: makeMoveNodeDownMultiSelectionEdges(
            parentAID: parentAID,
            parentBID: parentBID,
            focusedID: focusedID,
            selectedID: selectedID,
            lowerSiblingID: lowerSiblingID
        ),
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID]
    )

    return MoveNodeDownMultiSelectionFixture(
        graph: graph,
        parentAID: parentAID,
        focusedID: focusedID,
        selectedID: selectedID,
        lowerSiblingID: lowerSiblingID
    )
}

private func makeMoveNodeDownMultiSelectionNodes(
    parentAID: CanvasNodeID,
    parentBID: CanvasNodeID,
    focusedID: CanvasNodeID,
    selectedID: CanvasNodeID,
    lowerSiblingID: CanvasNodeID
) -> [CanvasNodeID: CanvasNode] {
    [
        parentAID: CanvasNode(
            id: parentAID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
        ),
        parentBID: CanvasNode(
            id: parentBID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 0, y: 220, width: 220, height: 120)
        ),
        focusedID: CanvasNode(
            id: focusedID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 260, y: 0, width: 220, height: 120)
        ),
        selectedID: CanvasNode(
            id: selectedID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 260, y: 220, width: 220, height: 120)
        ),
        lowerSiblingID: CanvasNode(
            id: lowerSiblingID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 260, y: 400, width: 220, height: 120)
        ),
    ]
}

private func makeMoveNodeDownMultiSelectionEdges(
    parentAID: CanvasNodeID,
    parentBID: CanvasNodeID,
    focusedID: CanvasNodeID,
    selectedID: CanvasNodeID,
    lowerSiblingID: CanvasNodeID
) -> [CanvasEdgeID: CanvasEdge] {
    [
        CanvasEdgeID(rawValue: "edge-parent-a-focused"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-parent-a-focused"),
            fromNodeID: parentAID,
            toNodeID: focusedID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-parent-a-lower"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-parent-a-lower"),
            fromNodeID: parentAID,
            toNodeID: lowerSiblingID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-parent-b-selected"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-parent-b-selected"),
            fromNodeID: parentBID,
            toNodeID: selectedID,
            relationType: .parentChild
        ),
    ]
}

private struct MoveNodeRightMultiSelectionFixture {
    let graph: CanvasGraph
    let previousID: CanvasNodeID
    let focusedID: CanvasNodeID
    let selectedChildID: CanvasNodeID
}

private func makeMoveNodeRightMultiSelectionFixture() -> MoveNodeRightMultiSelectionFixture {
    let rootID = CanvasNodeID(rawValue: "root")
    let previousID = CanvasNodeID(rawValue: "previous")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let selectedChildID = CanvasNodeID(rawValue: "selected-child")

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
                bounds: CanvasBounds(x: 260, y: 0, width: 220, height: 120)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 260, y: 220, width: 220, height: 120)
            ),
            selectedChildID: CanvasNode(
                id: selectedChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 520, y: 220, width: 220, height: 120)
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
            CanvasEdgeID(rawValue: "edge-focused-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-focused-child"),
                fromNodeID: focusedID,
                toNodeID: selectedChildID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedChildID]
    )

    return MoveNodeRightMultiSelectionFixture(
        graph: graph,
        previousID: previousID,
        focusedID: focusedID,
        selectedChildID: selectedChildID
    )
}

private struct MoveNodeRightCollapsedFocusFixture {
    let graph: CanvasGraph
    let previousID: CanvasNodeID
    let focusedID: CanvasNodeID
    let selectedChildID: CanvasNodeID
}

private func makeMoveNodeRightCollapsedFocusMultiSelectionFixture() -> MoveNodeRightCollapsedFocusFixture {
    let rootID = CanvasNodeID(rawValue: "root")
    let previousID = CanvasNodeID(rawValue: "previous-collapsed")
    let focusedID = CanvasNodeID(rawValue: "focused-collapsed")
    let selectedChildID = CanvasNodeID(rawValue: "selected-child-collapsed")

    let graph = makeMoveNodeRightCollapsedFocusGraph(
        rootID: rootID,
        previousID: previousID,
        focusedID: focusedID,
        selectedChildID: selectedChildID
    )

    return MoveNodeRightCollapsedFocusFixture(
        graph: graph,
        previousID: previousID,
        focusedID: focusedID,
        selectedChildID: selectedChildID
    )
}

private func makeMoveNodeRightCollapsedFocusGraph(
    rootID: CanvasNodeID,
    previousID: CanvasNodeID,
    focusedID: CanvasNodeID,
    selectedChildID: CanvasNodeID
) -> CanvasGraph {
    CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID, kind: .text, text: nil, bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)),
            previousID: CanvasNode(
                id: previousID, kind: .text, text: nil, bounds: CanvasBounds(x: 260, y: 0, width: 220, height: 120)),
            focusedID: CanvasNode(
                id: focusedID, kind: .text, text: nil, bounds: CanvasBounds(x: 260, y: 220, width: 220, height: 120)),
            selectedChildID: CanvasNode(
                id: selectedChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 520, y: 220, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-previous-collapsed"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-previous-collapsed"),
                fromNodeID: rootID,
                toNodeID: previousID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-focused-collapsed"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-focused-collapsed"),
                fromNodeID: rootID,
                toNodeID: focusedID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-focused-selected-collapsed"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-focused-selected-collapsed"),
                fromNodeID: focusedID,
                toNodeID: selectedChildID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedChildID],
        collapsedRootNodeIDs: [previousID]
    )
}
