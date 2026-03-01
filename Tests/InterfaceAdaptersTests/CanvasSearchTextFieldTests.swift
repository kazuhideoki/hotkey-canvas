import AppKit
import SwiftUI
import Testing

@testable import InterfaceAdapters

@Test("CanvasSearchTextField: Enter is not handled while marked text is active")
func test_control_insertNewline_withMarkedText_returnsFalseWithoutSubmit() {
    var textValue = ""
    let binding = Binding<String>(
        get: { textValue },
        set: { textValue = $0 }
    )

    var forwardCount = 0
    var backwardCount = 0
    let coordinator = CanvasSearchTextField.Coordinator(
        text: binding,
        onSubmitForward: { forwardCount += 1 },
        onSubmitBackward: { backwardCount += 1 },
        onMoveHistoryOlder: {},
        onMoveHistoryNewer: {},
        onTextEdited: {},
        onCancel: {}
    )

    let control = NSControl()
    let textView = MockMarkedTextView()
    textView.markedTextActive = true

    let handled = coordinator.control(
        control,
        textView: textView,
        doCommandBy: #selector(NSResponder.insertNewline(_:))
    )

    #expect(handled == false)
    #expect(forwardCount == 0)
    #expect(backwardCount == 0)
}

@Test("CanvasSearchTextField: Enter submits forward when marked text is inactive")
func test_control_insertNewline_withoutMarkedText_returnsTrueAndSubmitsForward() {
    var textValue = ""
    let binding = Binding<String>(
        get: { textValue },
        set: { textValue = $0 }
    )

    var forwardCount = 0
    var backwardCount = 0
    let coordinator = CanvasSearchTextField.Coordinator(
        text: binding,
        onSubmitForward: { forwardCount += 1 },
        onSubmitBackward: { backwardCount += 1 },
        onMoveHistoryOlder: {},
        onMoveHistoryNewer: {},
        onTextEdited: {},
        onCancel: {}
    )

    let control = NSControl()
    let textView = MockMarkedTextView()
    textView.markedTextActive = false

    let handled = coordinator.control(
        control,
        textView: textView,
        doCommandBy: #selector(NSResponder.insertNewline(_:))
    )

    #expect(handled)
    #expect(forwardCount == 1)
    #expect(backwardCount == 0)
}

@Test("CanvasSearchTextField: Up and Down invoke history navigation handlers")
func test_control_moveUpDown_invokesHistoryHandlers() {
    var textValue = ""
    let binding = Binding<String>(
        get: { textValue },
        set: { textValue = $0 }
    )

    var olderCount = 0
    var newerCount = 0
    let coordinator = CanvasSearchTextField.Coordinator(
        text: binding,
        onSubmitForward: {},
        onSubmitBackward: {},
        onMoveHistoryOlder: { olderCount += 1 },
        onMoveHistoryNewer: { newerCount += 1 },
        onTextEdited: {},
        onCancel: {}
    )
    let control = NSControl()
    let textView = MockMarkedTextView()

    let movedUp = coordinator.control(
        control,
        textView: textView,
        doCommandBy: #selector(NSResponder.moveUp(_:))
    )
    let movedDown = coordinator.control(
        control,
        textView: textView,
        doCommandBy: #selector(NSResponder.moveDown(_:))
    )

    #expect(movedUp)
    #expect(movedDown)
    #expect(olderCount == 1)
    #expect(newerCount == 1)
}

@Test("CanvasSearchTextField: Up and Down are not handled while marked text is active")
func test_control_moveUpDown_withMarkedText_doesNotInvokeHistoryHandlers() {
    var textValue = ""
    let binding = Binding<String>(
        get: { textValue },
        set: { textValue = $0 }
    )

    var olderCount = 0
    var newerCount = 0
    let coordinator = CanvasSearchTextField.Coordinator(
        text: binding,
        onSubmitForward: {},
        onSubmitBackward: {},
        onMoveHistoryOlder: { olderCount += 1 },
        onMoveHistoryNewer: { newerCount += 1 },
        onTextEdited: {},
        onCancel: {}
    )
    let control = NSControl()
    let textView = MockMarkedTextView()
    textView.markedTextActive = true

    let movedUp = coordinator.control(
        control,
        textView: textView,
        doCommandBy: #selector(NSResponder.moveUp(_:))
    )
    let movedDown = coordinator.control(
        control,
        textView: textView,
        doCommandBy: #selector(NSResponder.moveDown(_:))
    )

    #expect(movedUp == false)
    #expect(movedDown == false)
    #expect(olderCount == 0)
    #expect(newerCount == 0)
}

@Test("CanvasSearchTextField: text change updates binding and emits edit callback")
func test_controlTextDidChange_updatesBindingAndEditCallback() {
    var textValue = ""
    let binding = Binding<String>(
        get: { textValue },
        set: { textValue = $0 }
    )

    var editCount = 0
    let coordinator = CanvasSearchTextField.Coordinator(
        text: binding,
        onSubmitForward: {},
        onSubmitBackward: {},
        onMoveHistoryOlder: {},
        onMoveHistoryNewer: {},
        onTextEdited: { editCount += 1 },
        onCancel: {}
    )
    let textField = NSTextField()
    textField.stringValue = "updated query"

    coordinator.controlTextDidChange(Notification(name: .init("test"), object: textField))

    #expect(textValue == "updated query")
    #expect(editCount == 1)
}

private final class MockMarkedTextView: NSTextView {
    var markedTextActive = false

    override func hasMarkedText() -> Bool {
        markedTextActive
    }
}
