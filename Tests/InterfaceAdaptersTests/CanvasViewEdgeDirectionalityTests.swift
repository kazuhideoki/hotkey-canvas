import CoreGraphics
import Testing

@testable import InterfaceAdapters

@Test("CanvasView edge directionality: arrow metrics keep minimum readable size")
func test_edgeArrowMetrics_smallStrokeWidth_usesMinimums() {
    let metrics = CanvasView.edgeArrowMetrics(strokeWidth: 2)

    #expect(metrics.length == 8)
    #expect(metrics.halfWidth == 4)
}

@Test("CanvasView edge directionality: arrow metrics scale from stroke width in world space")
func test_edgeArrowMetrics_largeStrokeWidth_scalesWithStrokeWidth() {
    let metrics = CanvasView.edgeArrowMetrics(strokeWidth: 5)

    #expect(metrics.length == 14)
    #expect(metrics.halfWidth == 9)
}
