import Domain
import Testing

@testable import InterfaceAdapters

@Test("moveNode ショートカットが有効な場合に有効になる")
func test_shouldEnableCompositeMove_whenMoveNodeEnabled_returnsTrue() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .node,
        hasFocusedNode: true
    )

    let result = CanvasView.shouldEnableCompositeMove(
        direction: .right,
        context: context
    )

    #expect(result)
}

@Test("エリアターゲットで有効")
func test_shouldEnableCompositeMove_areaTarget_returnsTrue() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .area,
        hasFocusedNode: true
    )

    let result = CanvasView.shouldEnableCompositeMove(
        direction: .left,
        context: context
    )

    #expect(result)
}

@Test("フォーカス中のノードがない場合は無効になる")
func test_shouldEnableCompositeMove_withoutFocusedNode_returnsFalse() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .node,
        hasFocusedNode: false
    )

    let result = CanvasView.shouldEnableCompositeMove(
        direction: .up,
        context: context
    )

    #expect(!result)
}

@Test("エッジターゲットで無効になっています")
func test_shouldEnableCompositeMove_edgeTarget_returnsFalse() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true
    )

    let result = CanvasView.shouldEnableCompositeMove(
        direction: .up,
        context: context
    )

    #expect(!result)
}

@Test("ツリーエッジターゲットで無効になっています")
func test_shouldEnableCompositeMove_treeEdgeTarget_returnsFalse() {
    let context = KeymapExecutionContext(
        editingMode: .tree,
        operationTargetKind: .edge,
        hasFocusedNode: true
    )

    let result = CanvasView.shouldEnableCompositeMove(
        direction: .up,
        context: context
    )

    #expect(!result)
}

@Test("エリアターゲットは moveArea コマンドを解決する")
func test_compositeMoveCommand_areaTarget_resolvesMoveArea() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .area,
        hasFocusedNode: true
    )

    let command = CanvasView.compositeMoveCommand(
        direction: .left,
        context: context
    )

    #expect(command == .moveArea(.left))
}

@Test("ノードターゲットが moveNode コマンドを解決する")
func test_compositeMoveCommand_nodeTarget_resolvesMoveNode() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .node,
        hasFocusedNode: true
    )

    let command = CanvasView.compositeMoveCommand(
        direction: .left,
        context: context
    )

    #expect(command == .moveNode(.left))
}
