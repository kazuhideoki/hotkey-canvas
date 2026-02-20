import CoreGraphics
import Testing

@testable import InterfaceAdapters

@Test("CanvasViewportTransform: identity zoom maps world point to same screen point when offset is zero")
func test_pointOnScreen_identityZoom_noOffset() {
    let point = CanvasViewportTransform.pointOnScreen(
        worldPoint: CGPoint(x: 250, y: 180),
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )

    #expect(point.x == 250)
    #expect(point.y == 180)
}

@Test("CanvasViewportTransform: zoom in expands distance from viewport center")
func test_pointOnScreen_zoomIn_expandsFromCenter() {
    let point = CanvasViewportTransform.pointOnScreen(
        worldPoint: CGPoint(x: 650, y: 450),
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 2.0,
        effectiveOffset: .zero
    )

    #expect(point.x == 850)
    #expect(point.y == 600)
}

@Test("CanvasViewportTransform: zoom in and pan offset both affect transformed rect")
func test_rectOnScreen_zoomAndOffset_appliesBoth() {
    let rect = CanvasViewportTransform.rectOnScreen(
        worldRect: CGRect(x: 400, y: 260, width: 100, height: 80),
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 2.0,
        effectiveOffset: CGSize(width: 30, height: -10)
    )

    #expect(rect.origin.x == 380)
    #expect(rect.origin.y == 210)
    #expect(rect.width == 200)
    #expect(rect.height == 160)
}

@Test("CanvasViewportTransform: affine transform matches point conversion")
func test_affineTransform_matchesPointOnScreen() {
    let viewportSize = CGSize(width: 900, height: 600)
    let zoomScale = 1.5
    let effectiveOffset = CGSize(width: 40, height: -25)
    let worldPoint = CGPoint(x: 340, y: 210)

    let byPointAPI = CanvasViewportTransform.pointOnScreen(
        worldPoint: worldPoint,
        viewportSize: viewportSize,
        zoomScale: zoomScale,
        effectiveOffset: effectiveOffset
    )
    let byAffine = worldPoint.applying(
        CanvasViewportTransform.affineTransform(
            viewportSize: viewportSize,
            zoomScale: zoomScale,
            effectiveOffset: effectiveOffset
        )
    )

    #expect(byPointAPI.x == byAffine.x)
    #expect(byPointAPI.y == byAffine.y)
}
