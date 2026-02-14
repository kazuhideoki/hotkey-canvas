import AppKit
import Testing

@testable import InterfaceAdapters

@Test("NodeTextEditorTextView: Escape cancels editing")
func test_keyDown_escape_cancelsEditing() throws {
    var commitCount = 0
    var cancelCount = 0
    let sut = NodeTextEditorTextView()
    sut.onCommit = { commitCount += 1 }
    sut.onCancel = { cancelCount += 1 }
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53
        )
    )

    sut.keyDown(with: event)

    #expect(commitCount == 0)
    #expect(cancelCount == 1)
}
