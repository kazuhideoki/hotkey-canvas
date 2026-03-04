import Testing

@testable import InterfaceAdapters

@Test("CanvasView edge directionality: arrowhead scales up with zoom above 100% only")
func test_edgeArrowZoomCompensation_zoomAtOrAboveOne_returnsIdentity() {
    #expect(CanvasView.edgeArrowZoomCompensation(for: 1.0) == 1.0)
    #expect(CanvasView.edgeArrowZoomCompensation(for: 1.5) == 1.0)
    #expect(CanvasView.edgeArrowZoomCompensation(for: 4.0) == 1.0)
}

@Test("CanvasView edge directionality: arrowhead keeps size below 100% zoom")
func test_edgeArrowZoomCompensation_zoomBelowOne_returnsInverseScale() {
    #expect(CanvasView.edgeArrowZoomCompensation(for: 0.5) == 2.0)
    #expect(CanvasView.edgeArrowZoomCompensation(for: 0.25) == 4.0)
}
