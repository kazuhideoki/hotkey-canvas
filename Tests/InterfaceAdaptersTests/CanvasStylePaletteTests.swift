import Application
import Testing

@testable import InterfaceAdapters

@Test("CanvasStylePalette: default style sheet keeps current node and edge defaults")
func test_defaultStyleSheet_matchesCurrentNodeAndEdgeDefaults() {
    let styleSheet = CanvasStylePalette.defaultStyleSheet

    #expect(styleSheet.nodeText.fontSize == 20)
    #expect(styleSheet.nodeText.cornerRadius == 10)
    #expect(styleSheet.nodeText.focusedBorderLineWidth == 3)
    #expect(styleSheet.edge.lineWidth == 2.25)
}

@Test("CanvasStylePalette: default style sheet keeps current overlay defaults")
func test_defaultStyleSheet_matchesCurrentOverlayDefaults() {
    let styleSheet = CanvasStylePalette.defaultStyleSheet

    #expect(styleSheet.overlay.dimmedBackgroundOpacity == 0.12)
    #expect(styleSheet.overlay.popupSelectedRowOpacity == 0.2)
    #expect(styleSheet.overlay.popupUnselectedRowOpacity == 0.35)
    #expect(styleSheet.overlay.zoomPopupBorderOpacity == 0.55)
}

@Test("NodeTextStyle: style sheet injection overrides node text metrics")
func test_nodeTextStyle_usesInjectedNodeTextMetrics() {
    let base = CanvasStylePalette.defaultStyleSheet
    let injectedNodeText = CanvasNodeTextStyle(
        fontSize: 32,
        outerPadding: base.nodeText.outerPadding,
        editorContainerPadding: base.nodeText.editorContainerPadding,
        textContainerInset: base.nodeText.textContainerInset,
        imageTextSpacing: base.nodeText.imageTextSpacing,
        imageCornerRadius: base.nodeText.imageCornerRadius,
        cornerRadius: 18,
        borderLineWidth: base.nodeText.borderLineWidth,
        focusedBorderLineWidth: base.nodeText.focusedBorderLineWidth,
        collapsedBadgeFontSize: base.nodeText.collapsedBadgeFontSize,
        collapsedBadgeTrailingOffset: base.nodeText.collapsedBadgeTrailingOffset,
        markdownLineSpacing: base.nodeText.markdownLineSpacing,
        markdownBlockSpacing: base.nodeText.markdownBlockSpacing,
        markdownListMarkerSpacing: base.nodeText.markdownListMarkerSpacing,
        markdownCodeFontSize: base.nodeText.markdownCodeFontSize,
        markdownCodeBlockPadding: base.nodeText.markdownCodeBlockPadding,
        markdownCodeBlockCornerRadius: base.nodeText.markdownCodeBlockCornerRadius,
        markdownCodeBlockOpacity: base.nodeText.markdownCodeBlockOpacity,
        markdownCodeBorderLineWidth: base.nodeText.markdownCodeBorderLineWidth,
        markdownCodeBorderOpacity: base.nodeText.markdownCodeBorderOpacity,
        markdownCodeLeadingBarWidth: base.nodeText.markdownCodeLeadingBarWidth,
        markdownCodeLeadingBarOpacity: base.nodeText.markdownCodeLeadingBarOpacity,
        markdownCodeTextOpacity: base.nodeText.markdownCodeTextOpacity
    )
    let injectedStyleSheet = CanvasStyleSheet(
        nodeText: injectedNodeText,
        nodeChrome: base.nodeChrome,
        edge: base.edge,
        overlay: base.overlay
    )

    let style = NodeTextStyle(styleSheet: injectedStyleSheet)

    #expect(style.fontSize == 32)
    #expect(style.cornerRadius == 18)
}
