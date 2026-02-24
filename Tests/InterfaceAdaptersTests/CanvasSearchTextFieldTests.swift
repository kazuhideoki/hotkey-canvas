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

private final class MockMarkedTextView: NSTextView {
    var markedTextActive = false

    override func hasMarkedText() -> Bool {
        markedTextActive
    }
}
