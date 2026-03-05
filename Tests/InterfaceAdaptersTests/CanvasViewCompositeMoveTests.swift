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

@Test("CanvasView composite move: enabled in area target")
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

@Test("CanvasView composite move: disabled in edge target")
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

@Test("CanvasView composite move: area target resolves moveArea command")
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

@Test("CanvasView composite move: node target resolves moveNode command")
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
