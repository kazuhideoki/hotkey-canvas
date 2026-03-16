// 背景: Diagram の複数選択 move では、focused 以外も含む全移動 node の衝突解消が必要。
// 責務: group 内相対位置を保ったまま、非 focused な選択 node の重なり解消を検証する。
import Application
import Domain
import Testing

@Test("ダイアグラムエリアの moveNode は、フォーカスされていない選択されたノードの重複を解決する")
func test_apply_moveNodeInDiagramArea_multiSelection_resolvesOverlapForNonFocusedSelectedNode() async throws {
    let fixture = makeMoveNodeDiagramSelectionOverlapFixture()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture.graph)

    let result = try await sut.apply(commands: [.moveNode(.down)])

    let focusedAfter = try #require(result.newState.nodesByID[fixture.focusedID])
    let selectedAfter = try #require(result.newState.nodesByID[fixture.selectedID])
    let blockerAfter = try #require(result.newState.nodesByID[fixture.blockerID])
    #expect(focusedAfter.bounds.x == 440)
    #expect(focusedAfter.bounds.y == 440)
    #expect(
        selectionOverlapBounds(
            selectedAfter.bounds,
            blockerAfter.bounds,
            spacing: 16
        ) == false
    )
    #expect(selectedAfter.bounds.x - focusedAfter.bounds.x == 440)
    #expect(selectedAfter.bounds.y - focusedAfter.bounds.y == 0)
}

@Test("ノード ID がレガシー合成クラスター プレフィックスと一致する場合、ダイアグラムエリアの moveNode は衝突しない")
func test_apply_moveNodeInDiagramArea_avoidsBodyIDNamespaceCollision() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let focusedID = CanvasNodeID(rawValue: "selected")
    let selectedID = CanvasNodeID(rawValue: "other")
    let collidingNodeID = CanvasNodeID(rawValue: "diagram-selection:other,selected")
    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 440, y: 0, width: 220, height: 220)
            ),
            selectedID: CanvasNode(
                id: selectedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 880, y: 0, width: 220, height: 220)
            ),
            collidingNodeID: CanvasNode(
                id: collidingNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 880, y: 440, width: 220, height: 220)
            ),
        ],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID],
        areasByID: [
            areaID: CanvasArea(
                id: areaID,
                nodeIDs: [focusedID, selectedID, collidingNodeID],
                editingMode: .diagram
            )
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.down)])

    let focusedAfter = try #require(result.newState.nodesByID[focusedID])
    let blockerAfter = try #require(result.newState.nodesByID[collidingNodeID])
    #expect(focusedAfter.bounds.x == 440)
    #expect(focusedAfter.bounds.y == 440)
    #expect(selectionOverlapBounds(focusedAfter.bounds, blockerAfter.bounds, spacing: 16) == false)
}

private struct MoveNodeDiagramSelectionOverlapFixture {
    let graph: CanvasGraph
    let focusedID: CanvasNodeID
    let selectedID: CanvasNodeID
    let blockerID: CanvasNodeID
}

private func makeMoveNodeDiagramSelectionOverlapFixture() -> MoveNodeDiagramSelectionOverlapFixture {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let anchorID = CanvasNodeID(rawValue: "anchor")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let selectedID = CanvasNodeID(rawValue: "selected")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edgeID = CanvasEdgeID(rawValue: "edge-anchor-focused")
    let graph = CanvasGraph(
        nodesByID: [
            anchorID: CanvasNode(
                id: anchorID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 440, y: 0, width: 220, height: 220)
            ),
            selectedID: CanvasNode(
                id: selectedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 880, y: 0, width: 220, height: 220)
            ),
            blockerID: CanvasNode(
                id: blockerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 880, y: 440, width: 220, height: 220)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: anchorID,
                toNodeID: focusedID,
                relationType: .normal
            )
        ],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID],
        areasByID: [
            areaID: CanvasArea(
                id: areaID,
                nodeIDs: [anchorID, focusedID, selectedID, blockerID],
                editingMode: .diagram
            )
        ]
    )
    return MoveNodeDiagramSelectionOverlapFixture(
        graph: graph,
        focusedID: focusedID,
        selectedID: selectedID,
        blockerID: blockerID
    )
}

private func selectionOverlapBounds(
    _ lhs: CanvasBounds,
    _ rhs: CanvasBounds,
    spacing: Double = 0
) -> Bool {
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
