import Testing

@testable import InterfaceAdapters

@Test("ズームインすると、設定された次に大きなスケールに移動する")
func test_nextZoomScale_zoomIn_movesToLargerStep() {
    let scale = CanvasView.nextZoomScale(for: .zoomIn, currentScale: 1.0)
    #expect(scale == 1.25)
}

@Test("ズームアウトすると、次に小さい設定されたスケールに移動する")
func test_nextZoomScale_zoomOut_movesToSmallerStep() {
    let scale = CanvasView.nextZoomScale(for: .zoomOut, currentScale: 1.0)
    #expect(scale == 0.75)
}

@Test("ズームインは設定された最大値に固定される")
func test_nextZoomScale_zoomIn_clampsAtMaximum() {
    let scale = CanvasView.nextZoomScale(for: .zoomIn, currentScale: 4.0)
    #expect(scale == 4.0)
}

@Test("ズームアウトは設定された最小値に固定される")
func test_nextZoomScale_zoomOut_clampsAtMinimum() {
    let scale = CanvasView.nextZoomScale(for: .zoomOut, currentScale: 0.25)
    #expect(scale == 0.25)
}

@Test("比率テキストは四捨五入されたパーセントとしてレンダリングされる")
func test_zoomRatioText_rendersRoundedPercent() {
    let text = CanvasView.zoomRatioText(for: 1.25)
    #expect(text == "125%")
}
