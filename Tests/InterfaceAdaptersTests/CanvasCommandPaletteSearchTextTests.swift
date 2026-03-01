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

@Test("Command palette recent ordering: recent top 5 are pinned above alphabetical items")
func test_commandPaletteRecentOrdering_pinsTopFiveRecentItems() {
    let items: [CanvasView.CommandPaletteItem] = [
        .init(id: "a", title: "A", shortcutLabel: "", searchText: "", action: .insertImageFromFinder),
        .init(id: "b", title: "B", shortcutLabel: "", searchText: "", action: .insertImageFromFinder),
        .init(id: "c", title: "C", shortcutLabel: "", searchText: "", action: .insertImageFromFinder),
        .init(id: "d", title: "D", shortcutLabel: "", searchText: "", action: .insertImageFromFinder),
        .init(id: "e", title: "E", shortcutLabel: "", searchText: "", action: .insertImageFromFinder),
        .init(id: "f", title: "F", shortcutLabel: "", searchText: "", action: .insertImageFromFinder),
        .init(id: "g", title: "G", shortcutLabel: "", searchText: "", action: .insertImageFromFinder),
    ]

    let ordered = CanvasView.commandPaletteItemsPrioritizingRecent(
        items,
        recentItemIDs: ["f", "c", "g", "a", "e", "b"],
        maxPinnedCount: 5
    )

    #expect(ordered.map(\.id) == ["f", "c", "g", "a", "e", "b", "d"])
}

@Test("Command palette recent ordering: unknown ids in history are ignored")
func test_commandPaletteRecentOrdering_ignoresUnknownRecentIDs() {
    let items: [CanvasView.CommandPaletteItem] = [
        .init(id: "alpha", title: "Alpha", shortcutLabel: "", searchText: "", action: .insertImageFromFinder),
        .init(id: "beta", title: "Beta", shortcutLabel: "", searchText: "", action: .insertImageFromFinder),
    ]

    let ordered = CanvasView.commandPaletteItemsPrioritizingRecent(
        items,
        recentItemIDs: ["missing", "beta"],
        maxPinnedCount: 5
    )

    #expect(ordered.map(\.id) == ["beta", "alpha"])
}
