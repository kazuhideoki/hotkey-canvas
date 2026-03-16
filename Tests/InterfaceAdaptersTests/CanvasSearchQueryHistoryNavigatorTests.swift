import Testing

@testable import InterfaceAdapters

@Test("Up は最新のエントリから開始され、ドラフトが保存される")
func test_navigate_older_withoutCursor_startsFromLatestAndStoresDraft() {
    let result = CanvasSearchQueryHistoryNavigator.navigate(
        query: "in-progress",
        history: ["latest", "older"],
        cursor: nil,
        draft: "",
        direction: .older
    )

    #expect(result.query == "latest")
    #expect(result.cursor == 0)
    #expect(result.draft == "in-progress")
}

@Test("古いエントリに向けてステップアップ")
func test_navigate_older_withCursor_movesTowardOlderEntries() {
    let result = CanvasSearchQueryHistoryNavigator.navigate(
        query: "latest",
        history: ["latest", "older", "oldest"],
        cursor: 0,
        draft: "draft",
        direction: .older
    )

    #expect(result.query == "older")
    #expect(result.cursor == 1)
    #expect(result.draft == "draft")
}

@Test("ダウンすると、最新のエントリの後に下書きが復元される")
func test_navigate_newer_fromLatest_restoresDraft() {
    let result = CanvasSearchQueryHistoryNavigator.navigate(
        query: "latest",
        history: ["latest", "older"],
        cursor: 0,
        draft: "typed text",
        direction: .newer
    )

    #expect(result.query == "typed text")
    #expect(result.cursor == nil)
    #expect(result.draft == "typed text")
}

@Test("レコードの重複排除と空白のトリミング")
func test_record_deduplicatesAndTrimsWhitespace() {
    let result = CanvasSearchQueryHistoryNavigator.record(
        query: "  find me  ",
        history: ["alpha", "find me", "beta"],
        limit: 10
    )

    #expect(result == ["find me", "alpha", "beta"])
}

@Test("ユーザー編集によりカーソルがクリアされ、編集されたクエリが下書きとして保持される")
func test_userEditedQuery_clearsCursorAndSetsDraft() {
    let result = CanvasSearchQueryHistoryNavigator.userEditedQuery(
        currentQuery: "edited",
        cursor: 2
    )

    #expect(result.cursor == nil)
    #expect(result.draft == "edited")
}
