import AppKit
import Testing

@testable import InterfaceAdapters

@Test("T キーはツリー モードを選択する")
func test_action_tKey_returnsSelectTree() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "t", keyCode: 17))

    #expect(action == .selectTree)
}

@Test("D キーはダイアグラム モードを選択する")
func test_action_dKey_returnsSelectDiagram() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "D", keyCode: 2))

    #expect(action == .selectDiagram)
}

@Test("上矢印で選択範囲を上に移動する")
func test_action_upArrow_returnsMoveSelectionMinusOne() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "↑", keyCode: 126))

    #expect(action == .moveSelection(delta: -1))
}

@Test("下矢印で選択範囲を下に移動する")
func test_action_downArrow_returnsMoveSelectionPlusOne() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "↓", keyCode: 125))

    #expect(action == .moveSelection(delta: 1))
}

@Test("Enter で現在の選択を確認する")
func test_action_enter_returnsConfirmSelection() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "\r", keyCode: 36))

    #expect(action == .confirmSelection)
}

@Test("エスケープするとポップアップが閉じる")
func test_action_escape_returnsDismiss() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "\u{1B}", keyCode: 53))

    #expect(action == .dismiss)
}

@Test("無関係なキーは nil を返す")
func test_action_unrelatedKey_returnsNil() throws {
    let sut = AddNodeModeSelectionHotkeyResolver()

    let action = sut.action(for: try makeKeyDownEvent(characters: "x", keyCode: 7))

    #expect(action == nil)
}

@Test("keyDown 以外のイベントは nil を返す")
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
