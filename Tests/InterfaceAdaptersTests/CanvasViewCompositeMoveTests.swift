import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasView composite move: enabled when moveNode shortcut is enabled")
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

@Test("CanvasView composite move: disabled in area target")
func test_shouldEnableCompositeMove_areaTarget_returnsFalse() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .area,
        hasFocusedNode: true
    )

    let result = CanvasView.shouldEnableCompositeMove(
        direction: .left,
        context: context
    )

    #expect(!result)
}

@Test("CanvasView composite move: disabled when no focused node")
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
