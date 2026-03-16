import CoreGraphics
import Testing

@testable import InterfaceAdapters

@Test("自動センター、手動パン、アクティブドラッグオフセットを組み合わせます")
func test_combinedOffset_addsAllOffsets() {
    let result = CanvasViewportPanPolicy.combinedOffset(
        autoCenterOffset: CGSize(width: 120, height: -50),
        manualPanOffset: CGSize(width: 30, height: 40),
        activeDragOffset: CGSize(width: -10, height: 5)
    )

    #expect(result.width == 140)
    #expect(result.height == -5)
}

@Test("最新のドラッグ変換を追加して手動パンを更新する")
func test_updatedManualPanOffset_accumulatesTranslation() {
    let result = CanvasViewportPanPolicy.updatedManualPanOffset(
        current: CGSize(width: 15, height: -25),
        translation: CGSize(width: 45, height: 5)
    )

    #expect(result.width == 60)
    #expect(result.height == -20)
}

@Test("不正確なスクロールホイールデルタをスケールする")
func test_scrollWheelTranslation_scalesLineBasedDeltas() {
    let translation = CanvasViewportPanPolicy.scrollWheelTranslation(
        deltaX: 2,
        deltaY: -3,
        hasPreciseDeltas: false
    )

    #expect(translation.width == 32)
    #expect(translation.height == -48)
}

@Test("正確なスクロールホイールデルタをスケールなしで維持する")
func test_scrollWheelTranslation_keepsPreciseDeltas() {
    let translation = CanvasViewportPanPolicy.scrollWheelTranslation(
        deltaX: -1.5,
        deltaY: 4,
        hasPreciseDeltas: true
    )

    #expect(translation.width == -1.5)
    #expect(translation.height == 4)
}

@Test("フォーカス中のノードが完全に表示されている場合、ゼロ補正を返す")
func test_overflowCompensation_returnsZero_whenFocusRectIsVisible() {
    let compensation = CanvasViewportPanPolicy.overflowCompensation(
        focusRect: CGRect(x: 120, y: 80, width: 200, height: 120),
        viewportSize: CGSize(width: 800, height: 600),
        effectiveOffset: CGSize(width: 0, height: 0)
    )

    #expect(compensation == .zero)
}

@Test("各軸のオーバーフローを最小限の量で補正する")
func test_overflowCompensation_returnsMinimalOverflowAmount() {
    let compensation = CanvasViewportPanPolicy.overflowCompensation(
        focusRect: CGRect(x: 760, y: -20, width: 120, height: 80),
        viewportSize: CGSize(width: 800, height: 600),
        effectiveOffset: CGSize(width: 0, height: 0)
    )

    #expect(compensation.width == -80)
    #expect(compensation.height == 20)
}

@Test("zoomScaleToFit はスケールを縮小してビューポート内でフォーカス中の形状を維持する")
func test_zoomScaleToFit_shrinksScale_whenFocusedShapeIsLargerThanViewport() {
    let scale = CanvasViewportPanPolicy.zoomScaleToFit(
        focusRect: CGRect(x: 0, y: 0, width: 1_600, height: 900),
        viewportSize: CGSize(width: 800, height: 600),
        currentZoomScale: 1.0,
        minimumZoomScale: 0.25
    )

    #expect(scale == 0.5)
}

@Test("zoomScaleToFit は、フォーカス中の形状がすでにフィットしている場合に現在のスケールを維持する")
func test_zoomScaleToFit_keepsCurrentScale_whenFocusedShapeFits() {
    let scale = CanvasViewportPanPolicy.zoomScaleToFit(
        focusRect: CGRect(x: 0, y: 0, width: 300, height: 200),
        viewportSize: CGSize(width: 800, height: 600),
        currentZoomScale: 1.0,
        minimumZoomScale: 0.25
    )

    #expect(scale == 1.0)
}

@Test("zoomScaleToFit は最小ズームスケールを尊重する")
func test_zoomScaleToFit_respectsMinimumScale() {
    let scale = CanvasViewportPanPolicy.zoomScaleToFit(
        focusRect: CGRect(x: 0, y: 0, width: 8_000, height: 6_000),
        viewportSize: CGSize(width: 800, height: 600),
        currentZoomScale: 1.0,
        minimumZoomScale: 0.25
    )

    #expect(scale == 0.25)
}
