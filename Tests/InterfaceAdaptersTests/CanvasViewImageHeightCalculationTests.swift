import CoreGraphics
import Testing

@testable import InterfaceAdapters

@Test("CanvasView image size: measured display width does not upscale small images")
func test_measuredImageDisplayWidth_smallImage_doesNotUpscale() {
    let imageSize = CGSize(width: 80, height: 40)

    let width = CanvasView.measuredImageDisplayWidth(imageSize: imageSize, nodeWidth: 220)

    #expect(width == 80)
}

@Test("CanvasView image size: measured display width clamps to content width")
func test_measuredImageDisplayWidth_largeImage_clampsToContentWidth() {
    let imageSize = CGSize(width: 640, height: 320)
    let expectedContentWidth = 220.0 - (Double(NodeTextStyle.outerPadding) * 2)

    let width = CanvasView.measuredImageDisplayWidth(imageSize: imageSize, nodeWidth: 220)

    #expect(width == expectedContentWidth)
}

@Test("CanvasView image size: diagram image side keeps minimum for small image")
func test_diagramImageNodeSideLength_smallImage_keepsMinimumDiagramSide() {
    let imageSize = CGSize(width: 80, height: 40)

    let side = CanvasView.diagramImageNodeSideLength(imageSize: imageSize, currentNodeWidth: 220)

    #expect(side == 220)
}

@Test("CanvasView image size: diagram image side clamps to maximum for large image")
func test_diagramImageNodeSideLength_largeImage_clampsToMaximum() {
    let imageSize = CGSize(width: 1200, height: 800)

    let side = CanvasView.diagramImageNodeSideLength(imageSize: imageSize, currentNodeWidth: 220)

    #expect(side == 330)
}

@Test("CanvasView image height: image-only editing keeps base text container height")
func test_imageAwareEditingNodeHeight_imageOnly_preservesMeasuredTextHeight() {
    let measuredTextHeight = 42.0
    let imageHeight = 120.0

    let height = CanvasView.imageAwareEditingNodeHeight(
        measuredTextHeight: measuredTextHeight,
        imageHeight: imageHeight,
        imageSpacing: 0
    )

    #expect(height == measuredTextHeight + imageHeight)
}

@Test("CanvasView image height: image+text editing includes spacing")
func test_imageAwareEditingNodeHeight_withText_includesSpacing() {
    let measuredTextHeight = 52.0
    let imageHeight = 100.0
    let imageSpacing = 10.0

    let height = CanvasView.imageAwareEditingNodeHeight(
        measuredTextHeight: measuredTextHeight,
        imageHeight: imageHeight,
        imageSpacing: imageSpacing
    )

    #expect(height == measuredTextHeight + imageHeight + imageSpacing)
}

@Test("CanvasView image replacement: stale previous image path falls back to text baseline")
func test_replacementBaseNodeHeight_stalePreviousImage_usesTextOnlyHeight() {
    let baseHeight = CanvasView.replacementBaseNodeHeight(
        currentNodeHeight: 300,
        currentImageHeight: 0,
        currentImageSpacing: 0,
        textOnlyHeight: 60,
        hadExistingImagePath: true
    )

    #expect(baseHeight == 60)
}

@Test("CanvasView image replacement: known previous image subtracts existing image height and spacing")
func test_replacementBaseNodeHeight_knownPreviousImage_subtractsCurrentImageLayout() {
    let baseHeight = CanvasView.replacementBaseNodeHeight(
        currentNodeHeight: 260,
        currentImageHeight: 120,
        currentImageSpacing: 10,
        textOnlyHeight: 55,
        hadExistingImagePath: true
    )

    #expect(baseHeight == 130)
}
