import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: toggleFoldFocusedSubtree folds focused descendants")
func test_apply_toggleFoldFocusedSubtree_foldsFocusedDescendants() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 200, height: 100)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 300, y: 40, width: 200, height: 100)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.toggleFoldFocusedSubtree])

    #expect(result.newState.focusedNodeID == rootID)
    #expect(result.newState.collapsedRootNodeIDs == [rootID])
    #expect(result.canUndo)
}

@Test("ApplyCanvasCommandsUseCase: toggleFoldFocusedSubtree toggles back to expanded")
func test_apply_toggleFoldFocusedSubtree_togglesBackToExpanded() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let foldedGraph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 200, height: 100)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 300, y: 40, width: 200, height: 100)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootID,
        collapsedRootNodeIDs: [rootID]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: foldedGraph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.toggleFoldFocusedSubtree])

    #expect(result.newState.collapsedRootNodeIDs.isEmpty)
}

@Test("ApplyCanvasCommandsUseCase: toggleFoldFocusedSubtree is no-op for leaf node")
func test_apply_toggleFoldFocusedSubtree_isNoOpForLeafNode() async throws {
    let leafID = CanvasNodeID(rawValue: "leaf")
    let graph = CanvasGraph(
        nodesByID: [
            leafID: CanvasNode(
                id: leafID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 200, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: leafID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.toggleFoldFocusedSubtree])

    #expect(result.newState == graph.withDefaultTreeAreaIfMissing())
    #expect(!result.canUndo)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus skips folded descendants")
func test_apply_moveFocus_skipsFoldedDescendants() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let hiddenChildID = CanvasNodeID(rawValue: "hidden-child")
    let visibleNodeID = CanvasNodeID(rawValue: "visible")
    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 200, height: 100)
            ),
            hiddenChildID: CanvasNode(
                id: hiddenChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 270, y: 40, width: 200, height: 100)
            ),
            visibleNodeID: CanvasNode(
                id: visibleNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 520, y: 40, width: 200, height: 100)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: hiddenChildID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootID,
        collapsedRootNodeIDs: [rootID]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveFocus(.right)])

    #expect(result.newState.focusedNodeID == visibleNodeID)
}
