import Testing

@testable import InterfaceAdapters

@Test("名詞-動詞タイトルは動詞-最初のエイリアスを追加する")
func test_commandPaletteSearchText_addsVerbFirstAlias() {
    let searchText = CanvasView.commandPaletteSearchText(
        title: "Node: Delete Selected",
        shortcutLabel: "⌫",
        searchTokens: []
    )

    #expect(CanvasView.commandPaletteVerbFirstAliases(from: "Node: Delete Selected") == ["Delete Selected Node"])
    #expect(searchText.contains("Delete Selected Node"))
}

@Test("名詞と動詞以外のタイトルはエイリアスを追加しない")
func test_commandPaletteSearchText_nonNounVerbTitle_hasNoAlias() {
    #expect(CanvasView.commandPaletteVerbFirstAliases(from: "Undo") == [])
}

@Test("最近のトップ 5 はアルファベット順の項目の上に固定されています")
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

@Test("履歴内の不明な ID は無視される")
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

@Test("空のクエリで最新の履歴を呼び出す")
func test_commandPaletteQueryHistoryTransition_upFromEmpty_recallsNewest() {
    let state = CanvasView.CommandPaletteQueryHistoryState(
        queryHistory: ["delete", "zoom", "align"],
        activeHistoryIndex: -1,
        draftQuery: ""
    )

    let transition = CanvasView.commandPaletteQueryHistoryTransition(
        currentQuery: "",
        state: state,
        direction: .up
    )

    #expect(transition.nextQuery == "delete")
    #expect(transition.nextState.activeHistoryIndex == 0)
    #expect(transition.nextState.draftQuery == "")
}

@Test("閲覧中は古いエントリに移動する")
func test_commandPaletteQueryHistoryTransition_upWhileBrowsing_movesOlder() {
    let state = CanvasView.CommandPaletteQueryHistoryState(
        queryHistory: ["delete", "zoom", "align"],
        activeHistoryIndex: 0,
        draftQuery: ""
    )

    let transition = CanvasView.commandPaletteQueryHistoryTransition(
        currentQuery: "delete",
        state: state,
        direction: .up
    )

    #expect(transition.nextQuery == "zoom")
    #expect(transition.nextState.activeHistoryIndex == 1)
}

@Test("ブラウジング中にクリックすると、新しいエントリに移動する")
func test_commandPaletteQueryHistoryTransition_downWhileBrowsing_movesNewer() {
    let state = CanvasView.CommandPaletteQueryHistoryState(
        queryHistory: ["delete", "zoom", "align"],
        activeHistoryIndex: 2,
        draftQuery: ""
    )

    let transition = CanvasView.commandPaletteQueryHistoryTransition(
        currentQuery: "align",
        state: state,
        direction: .down
    )

    #expect(transition.nextQuery == "zoom")
    #expect(transition.nextState.activeHistoryIndex == 1)
}

@Test("最新の時点でダウンすると、ドラフトが復元され、履歴モードが終了する")
func test_commandPaletteQueryHistoryTransition_downAtNewest_restoresDraft() {
    let state = CanvasView.CommandPaletteQueryHistoryState(
        queryHistory: ["delete", "zoom", "align"],
        activeHistoryIndex: 0,
        draftQuery: "d"
    )

    let transition = CanvasView.commandPaletteQueryHistoryTransition(
        currentQuery: "delete",
        state: state,
        direction: .down
    )

    #expect(transition.nextQuery == "d")
    #expect(transition.nextState.activeHistoryIndex == -1)
}

@Test("空ではないクエリを実行しても履歴の呼び出しは開始されない")
func test_commandPaletteQueryHistoryTransition_upFromNonEmpty_doesNotRecall() {
    let state = CanvasView.CommandPaletteQueryHistoryState(
        queryHistory: ["delete"],
        activeHistoryIndex: -1,
        draftQuery: ""
    )

    let transition = CanvasView.commandPaletteQueryHistoryTransition(
        currentQuery: "del",
        state: state,
        direction: .up
    )

    #expect(transition.nextQuery == nil)
    #expect(transition.nextState == state)
}

@Test("up は選択範囲が一番上にある場合にのみ履歴を使う")
func test_shouldHandleArrowAsQueryHistory_upRequiresTopSelection() {
    let state = CanvasView.CommandPaletteQueryHistoryState(
        queryHistory: ["delete"],
        activeHistoryIndex: -1,
        draftQuery: ""
    )

    let shouldHandleAtTop = CanvasView.shouldHandleArrowAsQueryHistory(
        direction: .up,
        selectedCommandIndex: 0,
        currentQuery: "",
        state: state
    )
    let shouldHandleAwayFromTop = CanvasView.shouldHandleArrowAsQueryHistory(
        direction: .up,
        selectedCommandIndex: 2,
        currentQuery: "",
        state: state
    )

    #expect(shouldHandleAtTop == true)
    #expect(shouldHandleAwayFromTop == false)
}

@Test("down は履歴の閲覧中に履歴を使う")
func test_shouldHandleArrowAsQueryHistory_downRequiresActiveHistory() {
    let inactive = CanvasView.CommandPaletteQueryHistoryState(
        queryHistory: ["delete"],
        activeHistoryIndex: -1,
        draftQuery: ""
    )
    let active = CanvasView.CommandPaletteQueryHistoryState(
        queryHistory: ["delete"],
        activeHistoryIndex: 0,
        draftQuery: ""
    )

    #expect(
        CanvasView.shouldHandleArrowAsQueryHistory(
            direction: .down,
            selectedCommandIndex: 0,
            currentQuery: "delete",
            state: inactive
        ) == false
    )
    #expect(
        CanvasView.shouldHandleArrowAsQueryHistory(
            direction: .down,
            selectedCommandIndex: 0,
            currentQuery: "delete",
            state: active
        ) == true
    )
}
