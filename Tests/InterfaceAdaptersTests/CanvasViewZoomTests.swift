import Testing

@testable import InterfaceAdapters

@Test("CanvasView zoom: zoom-in moves to next larger configured scale")
func test_nextZoomScale_zoomIn_movesToLargerStep() {
    let scale = CanvasView.nextZoomScale(for: .zoomIn, currentScale: 1.0)
    #expect(scale == 1.25)
}

@Test("CanvasView zoom: zoom-out moves to next smaller configured scale")
func test_nextZoomScale_zoomOut_movesToSmallerStep() {
    let scale = CanvasView.nextZoomScale(for: .zoomOut, currentScale: 1.0)
    #expect(scale == 0.75)
}

@Test("CanvasView zoom: zoom-in is clamped at configured maximum")
func test_nextZoomScale_zoomIn_clampsAtMaximum() {
    let scale = CanvasView.nextZoomScale(for: .zoomIn, currentScale: 4.0)
    #expect(scale == 4.0)
}

@Test("CanvasView zoom: zoom-out is clamped at configured minimum")
func test_nextZoomScale_zoomOut_clampsAtMinimum() {
    let scale = CanvasView.nextZoomScale(for: .zoomOut, currentScale: 0.25)
    #expect(scale == 0.25)
}

@Test("CanvasView zoom: ratio text renders as rounded percent")
func test_zoomRatioText_rendersRoundedPercent() {
    let text = CanvasView.zoomRatioText(for: 1.25)
    #expect(text == "125%")
}
