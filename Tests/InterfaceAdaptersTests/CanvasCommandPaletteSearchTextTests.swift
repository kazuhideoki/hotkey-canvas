import Testing

@testable import InterfaceAdapters

@Test("Command palette search text: noun-verb title adds verb-first alias")
func test_commandPaletteSearchText_addsVerbFirstAlias() {
    let searchText = CanvasView.commandPaletteSearchText(
        title: "Node: Delete Focused",
        shortcutLabel: "⌫",
        searchTokens: []
    )

    #expect(CanvasView.commandPaletteVerbFirstAliases(from: "Node: Delete Focused") == ["Delete Focused Node"])
    #expect(searchText.contains("Delete Focused Node"))
}

@Test("Command palette search text: non noun-verb title does not add alias")
func test_commandPaletteSearchText_nonNounVerbTitle_hasNoAlias() {
    #expect(CanvasView.commandPaletteVerbFirstAliases(from: "Undo") == [])
}
