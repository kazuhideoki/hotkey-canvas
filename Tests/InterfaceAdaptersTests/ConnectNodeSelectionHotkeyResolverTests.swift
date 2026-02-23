import AppKit
import Domain
import Testing

@testable import InterfaceAdapters

@Test("ConnectNodeSelectionHotkeyResolver: left arrow moves selection left")
func test_connectNodeSelection_action_leftArrow_returnsMoveSelectionLeft() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "←", keyCode: 123))

    #expect(action == .moveSelection(.left))
}

@Test("ConnectNodeSelectionHotkeyResolver: up arrow moves selection up")
func test_connectNodeSelection_action_upArrow_returnsMoveSelectionUp() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "↑", keyCode: 126))

    #expect(action == .moveSelection(.up))
}

@Test("ConnectNodeSelectionHotkeyResolver: down arrow moves selection down")
func test_connectNodeSelection_action_downArrow_returnsMoveSelectionDown() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "↓", keyCode: 125))

    #expect(action == .moveSelection(.down))
}

@Test("ConnectNodeSelectionHotkeyResolver: right arrow moves selection right")
func test_connectNodeSelection_action_rightArrow_returnsMoveSelectionRight() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "→", keyCode: 124))

    #expect(action == .moveSelection(.right))
}

@Test("ConnectNodeSelectionHotkeyResolver: Enter confirms selection")
func test_connectNodeSelection_action_enter_returnsConfirmSelection() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "\r", keyCode: 36))

    #expect(action == .confirmSelection)
}

@Test("ConnectNodeSelectionHotkeyResolver: Escape dismisses mode")
func test_connectNodeSelection_action_escape_returnsDismiss() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "\u{1B}", keyCode: 53))

    #expect(action == .dismiss)
}

@Test("ConnectNodeSelectionHotkeyResolver: unrelated key returns nil")
func test_connectNodeSelection_action_unrelatedKey_returnsNil() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "x", keyCode: 7))

    #expect(action == nil)
}

@Test("ConnectNodeSelectionHotkeyResolver: non-keyDown event returns nil")
func test_connectNodeSelection_action_nonKeyDownEvent_returnsNil() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "↑",
            charactersIgnoringModifiers: "↑",
            isARepeat: false,
            keyCode: 126
        )
    )

    let action = sut.action(for: event)

    #expect(action == nil)
}

private func makeKeyDownEvent(characters: String, keyCode: UInt16) throws -> NSEvent {
    try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters.lowercased(),
            isARepeat: false,
            keyCode: keyCode
        )
    )
}
