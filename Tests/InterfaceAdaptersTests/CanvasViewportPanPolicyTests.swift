import CoreGraphics
import Testing

@testable import InterfaceAdapters

@Test("CanvasViewportPanPolicy: combines auto-center, manual pan, and active drag offsets")
func test_combinedOffset_addsAllOffsets() {
    let result = CanvasViewportPanPolicy.combinedOffset(
        autoCenterOffset: CGSize(width: 120, height: -50),
        manualPanOffset: CGSize(width: 30, height: 40),
        activeDragOffset: CGSize(width: -10, height: 5)
    )

    #expect(result.width == 140)
    #expect(result.height == -5)
}

@Test("CanvasViewportPanPolicy: updates manual pan by adding latest drag translation")
func test_updatedManualPanOffset_accumulatesTranslation() {
    let result = CanvasViewportPanPolicy.updatedManualPanOffset(
        current: CGSize(width: 15, height: -25),
        translation: CGSize(width: 45, height: 5)
    )

    #expect(result.width == 60)
    #expect(result.height == -20)
}

@Test("CanvasViewportPanPolicy: scales non-precise scroll wheel deltas")
func test_scrollWheelTranslation_scalesLineBasedDeltas() {
    let translation = CanvasViewportPanPolicy.scrollWheelTranslation(
        deltaX: 2,
        deltaY: -3,
        hasPreciseDeltas: false
    )

    #expect(translation.width == 32)
    #expect(translation.height == -48)
}

@Test("CanvasViewportPanPolicy: keeps precise scroll wheel deltas unscaled")
func test_scrollWheelTranslation_keepsPreciseDeltas() {
    let translation = CanvasViewportPanPolicy.scrollWheelTranslation(
        deltaX: -1.5,
        deltaY: 4,
        hasPreciseDeltas: true
    )

    #expect(translation.width == -1.5)
    #expect(translation.height == 4)
}

@Test("CanvasViewportPanPolicy: returns zero compensation when focused node is fully visible")
func test_overflowCompensation_returnsZero_whenFocusRectIsVisible() {
    let compensation = CanvasViewportPanPolicy.overflowCompensation(
        focusRect: CGRect(x: 120, y: 80, width: 200, height: 120),
        viewportSize: CGSize(width: 800, height: 600),
        effectiveOffset: CGSize(width: 0, height: 0)
    )

    #expect(compensation == .zero)
}

@Test("CanvasViewportPanPolicy: compensates overflow on each axis by minimal amount")
func test_overflowCompensation_returnsMinimalOverflowAmount() {
    let compensation = CanvasViewportPanPolicy.overflowCompensation(
        focusRect: CGRect(x: 760, y: -20, width: 120, height: 80),
        viewportSize: CGSize(width: 800, height: 600),
        effectiveOffset: CGSize(width: 0, height: 0)
    )

    #expect(compensation.width == -80)
    #expect(compensation.height == 20)
}
