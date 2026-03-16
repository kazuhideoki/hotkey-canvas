import Application
import Testing

@testable import InterfaceAdapters

@Test("デフォルトのスタイルシートは現在のノードとエッジのデフォルトを保持する")
func test_defaultStyleSheet_matchesCurrentNodeAndEdgeDefaults() {
    let styleSheet = CanvasStylePalette.defaultStyleSheet

    #expect(styleSheet.nodeText.fontSize == 20)
    #expect(styleSheet.nodeText.cornerRadius == 10)
    #expect(styleSheet.nodeText.focusedBorderLineWidth == 3)
    #expect(styleSheet.edge.lineWidth == 2.25)
}

@Test("デフォルトのスタイルシートは現在のオーバーレイのデフォルトを維持する")
func test_defaultStyleSheet_matchesCurrentOverlayDefaults() {
    let styleSheet = CanvasStylePalette.defaultStyleSheet

    #expect(styleSheet.overlay.commandPaletteSurface == .panel)
    #expect(styleSheet.overlay.searchPanelSurface == .search)
    #expect(styleSheet.overlay.selectionPopupSurface == .popup)
    #expect(styleSheet.overlay.connectBannerSurface == .banner)
    #expect(styleSheet.overlay.transientFeedbackSurface == .transientFeedback)
    #expect(styleSheet.overlay.dimmedBackgroundOpacity == 0.12)
    #expect(styleSheet.overlay.popupSelectedRowOpacity == 0.2)
    #expect(styleSheet.overlay.popupUnselectedRowOpacity == 0.35)
    #expect(styleSheet.overlay.zoomPopupBorderOpacity == 0.55)
}

@Test("スタイルシートインジェクションはノードテキストメトリクスをオーバーライドする")
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
