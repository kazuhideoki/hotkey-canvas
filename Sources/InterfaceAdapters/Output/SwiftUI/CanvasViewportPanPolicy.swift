import CoreGraphics
// Background: Canvas viewport can be temporarily panned by pointer input
// while still supporting focus-centered navigation.
// Responsibility: Provide deterministic rules to combine auto-centering and manual panning offsets.
import Foundation

/// Policy for composing viewport offsets and deciding when manual pan should reset.
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
}
