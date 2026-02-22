import Application
import Domain
import Testing

// Background: Tree copy/cut/paste in phase A uses in-memory clipboard and reconstructs subtree with new IDs.
// Responsibility: Verify copy/cut/paste semantics, clipboard no-op behavior, and collapsed-parent expansion.
@Test("ApplyCanvasCommandsUseCase: copy focused subtree survives delete and pastes under next focused sibling")
func test_apply_copyThenDelete_thenPasteAsChild_underNextFocusedSibling() async throws {
    let fixture = CopyThenPasteFixture.make()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    _ = try await sut.apply(commands: [.copyFocusedSubtree])
    let deleteResult = try await sut.apply(commands: [.deleteFocusedNode])
    #expect(deleteResult.newState.focusedNodeID == fixture.targetID)

    let pasteResult = try await sut.apply(commands: [.pasteSubtreeAsChild])

    #expect(pasteResult.newState.nodesByID[fixture.sourceRootID] == nil)
    #expect(pasteResult.newState.nodesByID[fixture.sourceChildID] == nil)
    #expect(pasteResult.newState.nodesByID.count == 4)
    #expect(pasteResult.newState.focusedNodeID != nil)

    let pastedRootEdge = try #require(
        pasteResult.newState.edgesByID.values.first(where: {
            $0.relationType == .parentChild && $0.fromNodeID == fixture.targetID
        })
    )
    let pastedRootNode = try #require(pasteResult.newState.nodesByID[pastedRootEdge.toNodeID])
    #expect(pastedRootNode.id != fixture.sourceRootID)
    #expect(pastedRootNode.text == "source-root-text")
    #expect(pastedRootNode.markdownStyleEnabled == false)
    #expect(pastedRootNode.metadata["marker"] == "source-root")

    let pastedChildEdge = try #require(
        pasteResult.newState.edgesByID.values.first(where: {
            $0.relationType == .parentChild && $0.fromNodeID == pastedRootNode.id
        })
    )
    let pastedChildNode = try #require(pasteResult.newState.nodesByID[pastedChildEdge.toNodeID])
    #expect(pastedChildNode.id != fixture.sourceChildID)
    #expect(pastedChildNode.text == "source-child-text")
    #expect(pastedChildNode.markdownStyleEnabled == false)
    #expect(pastedChildNode.metadata["marker"] == "source-child")
}

@Test("ApplyCanvasCommandsUseCase: cut focused subtree then paste as child under next focused sibling")
func test_apply_cutThenPasteAsChild_underNextFocusedSibling() async throws {
    let fixture = CutThenPasteFixture.make()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    let cutResult = try await sut.apply(commands: [.cutFocusedSubtree])
    #expect(cutResult.newState.nodesByID[fixture.sourceRootID] == nil)
    #expect(cutResult.newState.nodesByID[fixture.sourceChildID] == nil)
    #expect(cutResult.newState.focusedNodeID == fixture.targetID)
    #expect(cutResult.newState.collapsedRootNodeIDs.contains(fixture.targetID))

    let pasteResult = try await sut.apply(commands: [.pasteSubtreeAsChild])
    #expect(pasteResult.newState.nodesByID.count == 5)
    #expect(!pasteResult.newState.collapsedRootNodeIDs.contains(fixture.targetID))

    let targetChildren = pasteResult.newState.edgesByID.values.filter {
        $0.relationType == .parentChild && $0.fromNodeID == fixture.targetID
    }
    #expect(targetChildren.count == 2)
}

@Test("ApplyCanvasCommandsUseCase: pasteSubtreeAsChild is no-op when clipboard is empty")
func test_apply_pasteSubtreeAsChild_noOpWhenClipboardIsEmpty() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: "focused",
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID
    ).withDefaultTreeAreaIfMissing()

    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)
    let result = try await sut.apply(commands: [.pasteSubtreeAsChild])

    #expect(result.newState == graph)
    #expect(!result.canUndo)
}

@Test("ApplyCanvasCommandsUseCase: copyFocusedSubtree does not recurse infinitely on cyclic parent-child graph")
func test_apply_copyFocusedSubtree_handlesParentChildCycle() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: CanvasNode(
                id: nodeAID,
                kind: .text,
                text: "A",
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
            ),
            nodeBID: CanvasNode(
                id: nodeBID,
                kind: .text,
                text: "B",
                bounds: CanvasBounds(x: 320, y: 48, width: 220, height: 120)
            ),
        ],
        edgesByID: makeEdges([
            EdgeDefinition(id: "edge-a-b", fromNodeID: nodeAID, toNodeID: nodeBID),
            EdgeDefinition(id: "edge-b-a", fromNodeID: nodeBID, toNodeID: nodeAID),
        ]),
        focusedNodeID: nodeAID
    ).withDefaultTreeAreaIfMissing()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.copyFocusedSubtree])

    #expect(result.newState == graph)
    #expect(!result.canUndo)
}

private struct CopyThenPasteFixture {
    let graph: CanvasGraph
    let sourceRootID: CanvasNodeID
    let sourceChildID: CanvasNodeID
    let targetID: CanvasNodeID

    static func make() -> Self {
        let parentID = CanvasNodeID(rawValue: "parent")
        let sourceRootID = CanvasNodeID(rawValue: "source-root")
        let sourceChildID = CanvasNodeID(rawValue: "source-child")
        let targetID = CanvasNodeID(rawValue: "target")
        let nodesByID: [CanvasNodeID: CanvasNode] = [
            parentID: CanvasNode(
                id: parentID,
                kind: .text,
                text: "parent",
                bounds: CanvasBounds(x: 40, y: 100, width: 220, height: 80)
            ),
            sourceRootID: CanvasNode(
                id: sourceRootID,
                kind: .text,
                text: "source-root-text",
                bounds: CanvasBounds(x: 320, y: 40, width: 220, height: 80),
                metadata: ["marker": "source-root"],
                markdownStyleEnabled: false
            ),
            sourceChildID: CanvasNode(
                id: sourceChildID,
                kind: .text,
                text: "source-child-text",
                bounds: CanvasBounds(x: 600, y: 40, width: 220, height: 80),
                metadata: ["marker": "source-child"],
                markdownStyleEnabled: false
            ),
            targetID: CanvasNode(
                id: targetID,
                kind: .text,
                text: "target-text",
                bounds: CanvasBounds(x: 320, y: 220, width: 220, height: 80)
            ),
        ]
        let edgesByID = makeEdges([
            EdgeDefinition(id: "edge-parent-source", fromNodeID: parentID, toNodeID: sourceRootID),
            EdgeDefinition(id: "edge-source-child", fromNodeID: sourceRootID, toNodeID: sourceChildID),
            EdgeDefinition(id: "edge-parent-target", fromNodeID: parentID, toNodeID: targetID),
        ])
        let graph = CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: edgesByID,
            focusedNodeID: sourceRootID
        ).withDefaultTreeAreaIfMissing()
        return Self(graph: graph, sourceRootID: sourceRootID, sourceChildID: sourceChildID, targetID: targetID)
    }
}

private struct CutThenPasteFixture {
    let graph: CanvasGraph
    let sourceRootID: CanvasNodeID
    let sourceChildID: CanvasNodeID
    let targetID: CanvasNodeID

    static func make() -> Self {
        let parentID = CanvasNodeID(rawValue: "parent")
        let sourceRootID = CanvasNodeID(rawValue: "source-root")
        let sourceChildID = CanvasNodeID(rawValue: "source-child")
        let targetID = CanvasNodeID(rawValue: "target")
        let targetChildID = CanvasNodeID(rawValue: "target-child")
        let nodesByID: [CanvasNodeID: CanvasNode] = [
            parentID: CanvasNode(
                id: parentID,
                kind: .text,
                text: "parent",
                bounds: CanvasBounds(x: 40, y: 100, width: 220, height: 80)
            ),
            sourceRootID: CanvasNode(
                id: sourceRootID,
                kind: .text,
                text: "source-root-text",
                bounds: CanvasBounds(x: 320, y: 40, width: 220, height: 80)
            ),
            sourceChildID: CanvasNode(
                id: sourceChildID,
                kind: .text,
                text: "source-child-text",
                bounds: CanvasBounds(x: 600, y: 40, width: 220, height: 80)
            ),
            targetID: CanvasNode(
                id: targetID,
                kind: .text,
                text: "target",
                bounds: CanvasBounds(x: 320, y: 220, width: 220, height: 80)
            ),
            targetChildID: CanvasNode(
                id: targetChildID,
                kind: .text,
                text: "target-child",
                bounds: CanvasBounds(x: 600, y: 220, width: 220, height: 80)
            ),
        ]
        let edgesByID = makeEdges([
            EdgeDefinition(id: "edge-parent-source", fromNodeID: parentID, toNodeID: sourceRootID),
            EdgeDefinition(id: "edge-source-child", fromNodeID: sourceRootID, toNodeID: sourceChildID),
            EdgeDefinition(id: "edge-parent-target", fromNodeID: parentID, toNodeID: targetID),
            EdgeDefinition(id: "edge-target-child", fromNodeID: targetID, toNodeID: targetChildID),
        ])
        let graph = CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: edgesByID,
            focusedNodeID: sourceRootID,
            collapsedRootNodeIDs: [targetID]
        ).withDefaultTreeAreaIfMissing()
        return Self(graph: graph, sourceRootID: sourceRootID, sourceChildID: sourceChildID, targetID: targetID)
    }
}

private struct EdgeDefinition {
    let id: String
    let fromNodeID: CanvasNodeID
    let toNodeID: CanvasNodeID
}

private func makeEdges(_ definitions: [EdgeDefinition]) -> [CanvasEdgeID: CanvasEdge] {
    var edgesByID: [CanvasEdgeID: CanvasEdge] = [:]
    for definition in definitions {
        let edgeID = CanvasEdgeID(rawValue: definition.id)
        edgesByID[edgeID] = CanvasEdge(
            id: edgeID,
            fromNodeID: definition.fromNodeID,
            toNodeID: definition.toNodeID,
            relationType: .parentChild
        )
    }
    return edgesByID
}
