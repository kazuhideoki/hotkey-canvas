import Testing

@testable import InterfaceAdapters

@Test("CommandPaletteQueryEditing: insertion uses current cursor position")
func test_inserting_insertsAtCursor() {
    let result = CommandPaletteQueryEditing.inserting("x", into: "abcd", cursorIndex: 2)

    #expect(result.query == "abxcd")
    #expect(result.cursorIndex == 3)
}

@Test("CommandPaletteQueryEditing: moved cursor stays inside bounds")
func test_movedCursorIndex_clampsToBounds() {
    let left = CommandPaletteQueryEditing.movedCursorIndex(from: 0, offset: -1, in: "abc")
    let right = CommandPaletteQueryEditing.movedCursorIndex(from: 3, offset: 1, in: "abc")

    #expect(left == 0)
    #expect(right == 3)
}

@Test("CommandPaletteQueryEditing: backward delete removes character before cursor")
func test_deletingBackward_removesCharacterBeforeCursor() {
    let result = CommandPaletteQueryEditing.deletingBackward(in: "abcd", cursorIndex: 2)

    #expect(result.query == "acd")
    #expect(result.cursorIndex == 1)
}

@Test("CommandPaletteQueryEditing: forward delete removes character at cursor")
func test_deletingForward_removesCharacterAtCursor() {
    let result = CommandPaletteQueryEditing.deletingForward(in: "abcd", cursorIndex: 2)

    #expect(result.query == "abd")
    #expect(result.cursorIndex == 2)
}

@Test("CommandPaletteQueryEditing: split returns prefix and suffix around cursor")
func test_split_returnsTextsAroundCursor() {
    let result = CommandPaletteQueryEditing.split("abcd", cursorIndex: 2)

    #expect(result.prefix == "ab")
    #expect(result.suffix == "cd")
}
