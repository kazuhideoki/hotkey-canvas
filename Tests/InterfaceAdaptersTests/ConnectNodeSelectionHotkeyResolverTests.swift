import AppKit
import Domain
import Testing

@testable import InterfaceAdapters

@Test("左矢印は選択範囲を左に移動する")
func test_connectNodeSelection_action_leftArrow_returnsMoveSelectionLeft() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "←", keyCode: 123))

    #expect(action == .moveSelection(.left))
}

@Test("上矢印で選択範囲を上に移動する")
func test_connectNodeSelection_action_upArrow_returnsMoveSelectionUp() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "↑", keyCode: 126))

    #expect(action == .moveSelection(.up))
}

@Test("下矢印で選択範囲を下に移動する")
func test_connectNodeSelection_action_downArrow_returnsMoveSelectionDown() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "↓", keyCode: 125))

    #expect(action == .moveSelection(.down))
}

@Test("右矢印で選択範囲を右に移動")
func test_connectNodeSelection_action_rightArrow_returnsMoveSelectionRight() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "→", keyCode: 124))

    #expect(action == .moveSelection(.right))
}

@Test("Enter で選択を確定する")
func test_connectNodeSelection_action_enter_returnsConfirmSelection() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "\r", keyCode: 36))

    #expect(action == .confirmSelection)
}

@Test("Escape でモードを終了する")
func test_connectNodeSelection_action_escape_returnsDismiss() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "\u{1B}", keyCode: 53))

    #expect(action == .dismiss)
}

@Test("無関係なキーは nil を返す")
func test_connectNodeSelection_action_unrelatedKey_returnsNil() throws {
    let sut = ConnectNodeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "x", keyCode: 7))

    #expect(action == nil)
}

@Test("keyDown 以外のイベントは nil を返す")
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
