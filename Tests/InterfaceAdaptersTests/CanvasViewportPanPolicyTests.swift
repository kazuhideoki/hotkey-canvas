import CoreGraphics
import Domain
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

    #expect(translation.width == -32)
    #expect(translation.height == 48)
}

@Test("CanvasViewportPanPolicy: keeps precise scroll wheel deltas unscaled")
func test_scrollWheelTranslation_keepsPreciseDeltas() {
    let translation = CanvasViewportPanPolicy.scrollWheelTranslation(
        deltaX: -1.5,
        deltaY: 4,
        hasPreciseDeltas: true
    )

    #expect(translation.width == 1.5)
    #expect(translation.height == -4)
}

@Test("CanvasViewportPanPolicy: focus unchanged does not reset manual pan")
func test_shouldResetManualPanOffsetOnFocusChange_returnsFalse_whenFocusUnchanged() {
    let focusedNodeID = CanvasNodeID(rawValue: "node-1")

    let shouldReset = CanvasViewportPanPolicy.shouldResetManualPanOffsetOnFocusChange(
        previousFocusedNodeID: focusedNodeID,
        currentFocusedNodeID: focusedNodeID
    )

    #expect(!shouldReset)
}

@Test("CanvasViewportPanPolicy: nil to nil focus does not reset manual pan")
func test_shouldResetManualPanOffsetOnFocusChange_returnsFalse_whenFocusBothNil() {
    let shouldReset = CanvasViewportPanPolicy.shouldResetManualPanOffsetOnFocusChange(
        previousFocusedNodeID: nil,
        currentFocusedNodeID: nil
    )

    #expect(!shouldReset)
}

@Test("CanvasViewportPanPolicy: nil to value focus resets manual pan")
func test_shouldResetManualPanOffsetOnFocusChange_returnsTrue_whenFocusBecomesNonNil() {
    let shouldReset = CanvasViewportPanPolicy.shouldResetManualPanOffsetOnFocusChange(
        previousFocusedNodeID: nil,
        currentFocusedNodeID: CanvasNodeID(rawValue: "node-1")
    )

    #expect(shouldReset)
}

@Test("CanvasViewportPanPolicy: value to nil focus resets manual pan")
func test_shouldResetManualPanOffsetOnFocusChange_returnsTrue_whenFocusBecomesNil() {
    let shouldReset = CanvasViewportPanPolicy.shouldResetManualPanOffsetOnFocusChange(
        previousFocusedNodeID: CanvasNodeID(rawValue: "node-1"),
        currentFocusedNodeID: nil
    )

    #expect(shouldReset)
}

@Test("CanvasViewportPanPolicy: value to different value focus resets manual pan")
func test_shouldResetManualPanOffsetOnFocusChange_returnsTrue_whenFocusChangesNode() {
    let shouldReset = CanvasViewportPanPolicy.shouldResetManualPanOffsetOnFocusChange(
        previousFocusedNodeID: CanvasNodeID(rawValue: "node-1"),
        currentFocusedNodeID: CanvasNodeID(rawValue: "node-2")
    )

    #expect(shouldReset)
}
