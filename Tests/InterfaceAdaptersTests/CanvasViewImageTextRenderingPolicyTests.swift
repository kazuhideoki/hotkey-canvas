import Testing

@testable import InterfaceAdapters

@Test("CanvasView image text policy: markdown render is disabled when search matches exist")
func test_shouldRenderMarkdownText_markdownEnabledWithSearchMatches_returnsFalse() {
    #expect(
        CanvasView.shouldRenderMarkdownText(
            markdownStyleEnabled: true,
            hasSearchMatches: true
        ) == false
    )
}

@Test("CanvasView image text policy: markdown render is enabled when no search matches exist")
func test_shouldRenderMarkdownText_markdownEnabledWithoutSearchMatches_returnsTrue() {
    #expect(
        CanvasView.shouldRenderMarkdownText(
            markdownStyleEnabled: true,
            hasSearchMatches: false
        ) == true
    )
}
