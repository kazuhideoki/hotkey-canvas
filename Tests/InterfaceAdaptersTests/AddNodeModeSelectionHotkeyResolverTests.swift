import AppKit
import Testing

@testable import InterfaceAdapters

@Test("AddNodeModeSelectionHotkeyResolver: T key selects tree mode")
func test_action_tKey_returnsSelectTree() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "t", keyCode: 17))

    #expect(action == .selectTree)
}

@Test("AddNodeModeSelectionHotkeyResolver: D key selects diagram mode")
func test_action_dKey_returnsSelectDiagram() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "D", keyCode: 2))

    #expect(action == .selectDiagram)
}

@Test("AddNodeModeSelectionHotkeyResolver: up arrow moves selection up")
func test_action_upArrow_returnsMoveSelectionMinusOne() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "↑", keyCode: 126))

    #expect(action == .moveSelection(delta: -1))
}

@Test("AddNodeModeSelectionHotkeyResolver: down arrow moves selection down")
func test_action_downArrow_returnsMoveSelectionPlusOne() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "↓", keyCode: 125))

    #expect(action == .moveSelection(delta: 1))
}

@Test("AddNodeModeSelectionHotkeyResolver: Enter confirms current selection")
func test_action_enter_returnsConfirmSelection() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "\r", keyCode: 36))

    #expect(action == .confirmSelection)
}

@Test("AddNodeModeSelectionHotkeyResolver: Escape dismisses popup")
func test_action_escape_returnsDismiss() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "\u{1B}", keyCode: 53))

    #expect(action == .dismiss)
}

@Test("AddNodeModeSelectionHotkeyResolver: unrelated key returns nil")
func test_action_unrelatedKey_returnsNil() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "x", keyCode: 7))

    #expect(action == nil)
}

@Test("AddNodeModeSelectionHotkeyResolver: non-keyDown event returns nil")
func test_action_nonKeyDownEvent_returnsNil() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "t",
            charactersIgnoringModifiers: "t",
            isARepeat: false,
            keyCode: 17
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
