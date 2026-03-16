import Testing

@testable import InterfaceAdapters

@Test("検索一致が存在する場合、マークダウン レンダリングは無効になる")
func test_shouldRenderMarkdownText_markdownEnabledWithSearchMatches_returnsFalse() {
    #expect(
        CanvasView.shouldRenderMarkdownText(
            markdownStyleEnabled: true,
            hasSearchMatches: true
        ) == false
    )
}

@Test("検索一致が存在しない場合、マークダウン レンダリングが有効になる")
func test_shouldRenderMarkdownText_markdownEnabledWithoutSearchMatches_returnsTrue() {
    #expect(
        CanvasView.shouldRenderMarkdownText(
            markdownStyleEnabled: true,
            hasSearchMatches: false
        ) == true
    )
}
