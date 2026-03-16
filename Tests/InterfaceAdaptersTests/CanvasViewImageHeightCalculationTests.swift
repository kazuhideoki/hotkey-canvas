import CoreGraphics
import Testing

@testable import InterfaceAdapters

@Test("測定された表示幅では小さな画像はアップスケールされない")
func test_measuredImageDisplayWidth_smallImage_doesNotUpscale() {
    let imageSize = CGSize(width: 80, height: 40)

    let width = CanvasView.measuredImageDisplayWidth(imageSize: imageSize, nodeWidth: 220)

    #expect(width == 80)
}

@Test("測定された表示幅はコンテンツの幅に固定される")
func test_measuredImageDisplayWidth_largeImage_clampsToContentWidth() {
    let imageSize = CGSize(width: 640, height: 320)
    let expectedContentWidth = 220.0 - (Double(NodeTextStyle.outerPadding) * 2)

    let width = CanvasView.measuredImageDisplayWidth(imageSize: imageSize, nodeWidth: 220)

    #expect(width == expectedContentWidth)
}

@Test("測定された表示幅 ノードコンテンツスケールごとに小さな画像をアップスケールする")
func test_measuredImageDisplayWidth_smallImage_withContentScale_upscales() {
    let imageSize = CGSize(width: 80, height: 40)

    let width = CanvasView.measuredImageDisplayWidth(
        imageSize: imageSize,
        nodeWidth: 220,
        nodeContentScale: 2
    )

    #expect(width == 160)
}

@Test("図画像側は小さい画像の場合は最小限に抑えます")
func test_diagramImageNodeSideLength_smallImage_keepsMinimumDiagramSide() {
    let imageSize = CGSize(width: 80, height: 40)

    let side = CanvasView.diagramImageNodeSideLength(imageSize: imageSize, currentNodeWidth: 220)

    #expect(side == 220)
}

@Test("図のイメージ側は、イメージの置換時に縮小されたノード幅を維持する")
func test_diagramImageNodeSideLength_smallImage_preservesShrunkDiagramNodeWidth() {
    let imageSize = CGSize(width: 80, height: 40)
    let shrunkNodeWidth = 132.0

    let side = CanvasView.diagramImageNodeSideLength(
        imageSize: imageSize,
        currentNodeWidth: shrunkNodeWidth
    )

    #expect(side == shrunkNodeWidth)
}

@Test("図 大きな画像の場合、画像側を最大にクランプする")
func test_diagramImageNodeSideLength_largeImage_clampsToMaximum() {
    let imageSize = CGSize(width: 1200, height: 800)

    let side = CanvasView.diagramImageNodeSideLength(imageSize: imageSize, currentNodeWidth: 220)

    #expect(side == 330)
}

@Test("画像のみの編集ではベーステキストコンテナの高さが維持される")
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

@Test("画像+テキスト編集にはスペースが含まれます")
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

@Test("古い画像パスはテキストベースラインに戻ります")
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

@Test("既知の以前の画像から既存の画像の高さと間隔が差し引かれます")
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
