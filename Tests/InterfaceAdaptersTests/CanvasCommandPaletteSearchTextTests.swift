import Testing

@testable import InterfaceAdapters

@Test("Command palette search text: noun-verb title adds verb-first alias")
func test_commandPaletteSearchText_addsVerbFirstAlias() {
    let searchText = CanvasView.commandPaletteSearchText(
        title: "Node: Delete Selected",
        shortcutLabel: "⌫",
        searchTokens: []
    )

    #expect(CanvasView.commandPaletteVerbFirstAliases(from: "Node: Delete Selected") == ["Delete Selected Node"])
    #expect(searchText.contains("Delete Selected Node"))
}

@Test("Command palette search text: non noun-verb title does not add alias")
func test_commandPaletteSearchText_nonNounVerbTitle_hasNoAlias() {
    #expect(CanvasView.commandPaletteVerbFirstAliases(from: "Undo") == [])
}
