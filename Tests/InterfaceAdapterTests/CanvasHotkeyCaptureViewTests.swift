import AppKit
import Testing

@testable import InterfaceAdapters

@Test("CanvasKeyCaptureNSView: handleKeyDown returns handler result")
func test_handleKeyDown_returnsHandlerResult() throws {
    var wasCalled = false
    let sut = CanvasKeyCaptureNSView(isEnabled: true) { _ in
        wasCalled = true
        return true
    }
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    let handled = sut.handleKeyDown(event)

    #expect(wasCalled)
    #expect(handled)
}
