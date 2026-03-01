import Testing

@testable import InterfaceAdapters

@Test("Search query history: Up starts from latest entry and stores draft")
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

@Test("Search query history: Up steps toward older entries")
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

@Test("Search query history: Down restores draft after newest entry")
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

@Test("Search query history: record deduplicates and trims whitespace")
func test_record_deduplicatesAndTrimsWhitespace() {
    let result = CanvasSearchQueryHistoryNavigator.record(
        query: "  find me  ",
        history: ["alpha", "find me", "beta"],
        limit: 10
    )

    #expect(result == ["find me", "alpha", "beta"])
}

@Test("Search query history: user edit clears cursor and keeps edited query as draft")
func test_userEditedQuery_clearsCursorAndSetsDraft() {
    let result = CanvasSearchQueryHistoryNavigator.userEditedQuery(
        currentQuery: "edited",
        cursor: 2
    )

    #expect(result.cursor == nil)
    #expect(result.draft == "edited")
}
