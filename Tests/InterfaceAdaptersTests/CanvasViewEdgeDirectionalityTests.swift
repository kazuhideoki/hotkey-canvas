import CoreGraphics
import Testing

@testable import InterfaceAdapters

@Test("矢印メトリクスは読み取り可能な最小サイズを維持する")
func test_edgeArrowMetrics_smallStrokeWidth_usesMinimums() {
    let metrics = CanvasView.edgeArrowMetrics(strokeWidth: 2)

    #expect(metrics.length == 8)
    #expect(metrics.halfWidth == 4)
}

@Test("矢印メトリクスはワールド空間のストローク幅からスケールする")
func test_edgeArrowMetrics_largeStrokeWidth_scalesWithStrokeWidth() {
    let metrics = CanvasView.edgeArrowMetrics(strokeWidth: 5)

    #expect(metrics.length == 14)
    #expect(metrics.halfWidth == 9)
}
