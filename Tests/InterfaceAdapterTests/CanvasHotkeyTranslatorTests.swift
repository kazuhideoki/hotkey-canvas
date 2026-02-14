import AppKit
import Domain
import InterfaceAdapters
import Testing

@Test("CanvasHotkeyTranslator: Shift+Enter maps to addNode")
func test_translate_shiftEnter_returnsAddNode() throws {
    let sut = CanvasHotkeyTranslator()
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

    let commands = sut.translate(event)

    #expect(commands == [.addNode])
}

@Test("CanvasHotkeyTranslator: Enter without Shift maps to no command")
func test_translate_enterWithoutShift_returnsEmpty() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    let commands = sut.translate(event)

    #expect(commands.isEmpty)
}
