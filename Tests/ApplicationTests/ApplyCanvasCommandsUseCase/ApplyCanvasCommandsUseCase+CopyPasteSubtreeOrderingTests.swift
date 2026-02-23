import Application
import Domain
import Testing

// Background: Tree paste previously mixed copied children with existing siblings due coordinate-based ordering.
// Responsibility: Verify pasted siblings are appended after existing children in tree mode.
@Test("ApplyCanvasCommandsUseCase: tree area paste appends copied siblings after existing children")
func test_apply_treeArea_pasteAppendsChildrenAfterExistingSiblings() async throws {
    let fixture = makeCopyPasteAppendOrderingFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    _ = try await sut.apply(commands: [.copyFocusedSubtree])
    let pasteResult = try await sut.apply(commands: [.pasteSubtreeAsChild])

    let childTexts = pasteResult.newState.edgesByID.values
        .filter { $0.relationType == .parentChild && $0.fromNodeID == fixture.targetID }
        .sorted { lhs, rhs in
            let lhsOrder = lhs.parentChildOrder ?? Int.max
            let rhsOrder = rhs.parentChildOrder ?? Int.max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
        .compactMap { edge in
            pasteResult.newState.nodesByID[edge.toNodeID]?.text
        }

    #expect(childTexts == ["e", "f", "g", "a", "b", "c"])
}

private struct CopyPasteAppendOrderingFixture {
    let targetID: CanvasNodeID
    let graph: CanvasGraph
}

private func makeCopyPasteAppendOrderingFixture() -> CopyPasteAppendOrderingFixture {
    let ids = CopyPasteAppendNodeIDs()
    let graph = CanvasGraph(
        nodesByID: makeCopyPasteAppendNodes(ids: ids),
        edgesByID: makeCopyPasteAppendEdges(ids: ids),
        focusedNodeID: ids.targetID,
        selectedNodeIDs: Set([ids.sourceAID, ids.sourceBID, ids.sourceCID])
    ).withDefaultTreeAreaIfMissing()

    return CopyPasteAppendOrderingFixture(targetID: ids.targetID, graph: graph)
}

private struct CopyPasteAppendNodeIDs {
    let targetID = CanvasNodeID(rawValue: "target")
    let existingEID = CanvasNodeID(rawValue: "existing-e")
    let existingFID = CanvasNodeID(rawValue: "existing-f")
    let existingGID = CanvasNodeID(rawValue: "existing-g")
    let sourceAID = CanvasNodeID(rawValue: "source-a")
    let sourceBID = CanvasNodeID(rawValue: "source-b")
    let sourceCID = CanvasNodeID(rawValue: "source-c")
}

private func makeCopyPasteAppendNodes(ids: CopyPasteAppendNodeIDs) -> [CanvasNodeID: CanvasNode] {
    [
        ids.targetID: CanvasNode(
            id: ids.targetID,
            kind: .text,
            text: "target",
            bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 80)
        ),
        ids.existingEID: CanvasNode(
            id: ids.existingEID,
            kind: .text,
            text: "e",
            bounds: CanvasBounds(x: 360, y: 40, width: 220, height: 80)
        ),
        ids.existingFID: CanvasNode(
            id: ids.existingFID,
            kind: .text,
            text: "f",
            bounds: CanvasBounds(x: 360, y: 160, width: 220, height: 80)
        ),
        ids.existingGID: CanvasNode(
            id: ids.existingGID,
            kind: .text,
            text: "g",
            bounds: CanvasBounds(x: 360, y: 280, width: 220, height: 80)
        ),
        ids.sourceAID: CanvasNode(
            id: ids.sourceAID,
            kind: .text,
            text: "a",
            bounds: CanvasBounds(x: 760, y: 20, width: 220, height: 80)
        ),
        ids.sourceBID: CanvasNode(
            id: ids.sourceBID,
            kind: .text,
            text: "b",
            bounds: CanvasBounds(x: 760, y: 140, width: 220, height: 80)
        ),
        ids.sourceCID: CanvasNode(
            id: ids.sourceCID,
            kind: .text,
            text: "c",
            bounds: CanvasBounds(x: 760, y: 260, width: 220, height: 80)
        ),
    ]
}

private func makeCopyPasteAppendEdges(ids: CopyPasteAppendNodeIDs) -> [CanvasEdgeID: CanvasEdge] {
    [
        CanvasEdgeID(rawValue: "edge-target-e"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-target-e"),
            fromNodeID: ids.targetID,
            toNodeID: ids.existingEID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-target-f"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-target-f"),
            fromNodeID: ids.targetID,
            toNodeID: ids.existingFID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-target-g"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-target-g"),
            fromNodeID: ids.targetID,
            toNodeID: ids.existingGID,
            relationType: .parentChild
        ),
    ]
}
