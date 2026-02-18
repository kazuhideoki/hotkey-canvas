import CoreGraphics
// Background: Canvas viewport can be temporarily panned by pointer input
// while still supporting focus-centered navigation.
// Responsibility: Provide deterministic rules to combine auto-centering and manual panning offsets.
import Foundation

/// Policy for composing viewport offsets from auto-centering and pointer interactions.
enum CanvasViewportPanPolicy {
    /// Combines offsets in rendering order: auto-centering + persisted manual pan + active drag translation.
    /// - Parameters:
    ///   - autoCenterOffset: Offset that keeps focused node at viewport center.
    ///   - manualPanOffset: Persisted manual pan accumulated from completed drags.
    ///   - activeDragOffset: Current drag translation while gesture is active.
    /// - Returns: Effective offset used for canvas rendering.
    static func combinedOffset(
        autoCenterOffset: CGSize,
        manualPanOffset: CGSize,
        activeDragOffset: CGSize
    ) -> CGSize {
        CGSize(
            width: autoCenterOffset.width + manualPanOffset.width + activeDragOffset.width,
            height: autoCenterOffset.height + manualPanOffset.height + activeDragOffset.height
        )
    }

    /// Accumulates persisted manual pan using the latest translation.
    /// - Parameters:
    ///   - current: Existing manual pan offset.
    ///   - translation: Translation to add to the current pan offset.
    /// - Returns: Updated manual pan offset.
    static func updatedManualPanOffset(current: CGSize, translation: CGSize) -> CGSize {
        CGSize(
            width: current.width + translation.width,
            height: current.height + translation.height
        )
    }

    /// Converts scroll-wheel deltas into canvas pan translation.
    /// - Parameters:
    ///   - deltaX: Raw horizontal wheel delta.
    ///   - deltaY: Raw vertical wheel delta.
    ///   - hasPreciseDeltas: True for trackpad/high-resolution devices.
    /// - Returns: Translation to accumulate into manual pan offset.
    static func scrollWheelTranslation(
        deltaX: Double,
        deltaY: Double,
        hasPreciseDeltas: Bool
    ) -> CGSize {
        let scale = hasPreciseDeltas ? 1.0 : 16.0
        return CGSize(
            width: -deltaX * scale,
            height: -deltaY * scale
        )
    }

    /// Computes the minimal offset delta required to keep a focused node fully visible.
    /// - Parameters:
    ///   - focusRect: Focused node frame in canvas/world coordinates.
    ///   - viewportSize: Current viewport size.
    ///   - effectiveOffset: Current effective offset applied to canvas rendering.
    /// - Returns: Offset delta to add so the focused node stays within viewport bounds.
    static func overflowCompensation(
        focusRect: CGRect,
        viewportSize: CGSize,
        effectiveOffset: CGSize
    ) -> CGSize {
        let minXOnScreen = focusRect.minX + effectiveOffset.width
        let maxXOnScreen = focusRect.maxX + effectiveOffset.width
        let minYOnScreen = focusRect.minY + effectiveOffset.height
        let maxYOnScreen = focusRect.maxY + effectiveOffset.height

        let dx: Double
        if minXOnScreen < 0 {
            dx = -minXOnScreen
        } else if maxXOnScreen > viewportSize.width {
            dx = viewportSize.width - maxXOnScreen
        } else {
            dx = 0
        }

        let dy: Double
        if minYOnScreen < 0 {
            dy = -minYOnScreen
        } else if maxYOnScreen > viewportSize.height {
            dy = viewportSize.height - maxYOnScreen
        } else {
            dy = 0
        }

        return CGSize(width: dx, height: dy)
    }
}
