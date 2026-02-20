// Background: Semantic zoom requires consistent world-to-screen conversion
// for nodes and focus visibility checks.
// Responsibility: Convert canvas world coordinates into screen coordinates
// using viewport center, zoom scale, and offset.
import CoreGraphics
import Foundation

/// Coordinate transform utilities shared by canvas rendering and viewport visibility logic.
enum CanvasViewportTransform {
    /// Affine transform that maps world-space coordinates to screen-space coordinates.
    /// - Parameters:
    ///   - viewportSize: Current viewport size.
    ///   - zoomScale: Active zoom scale.
    ///   - effectiveOffset: Screen-space offset after camera and manual panning are combined.
    /// - Returns: Transform that can be applied to SwiftUI `Path`.
    static func affineTransform(
        viewportSize: CGSize,
        zoomScale: Double,
        effectiveOffset: CGSize
    ) -> CGAffineTransform {
        let scale = CGFloat(zoomScale)
        let centerX = viewportSize.width / 2
        let centerY = viewportSize.height / 2
        let tx = centerX * (1 - scale) + effectiveOffset.width
        let ty = centerY * (1 - scale) + effectiveOffset.height
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
    }

    /// Converts a world-space point to a screen-space point.
    /// - Parameters:
    ///   - worldPoint: Point in world-space coordinates.
    ///   - viewportSize: Current viewport size.
    ///   - zoomScale: Active zoom scale.
    ///   - effectiveOffset: Screen-space offset after camera and manual panning are combined.
    /// - Returns: Point in screen-space coordinates.
    static func pointOnScreen(
        worldPoint: CGPoint,
        viewportSize: CGSize,
        zoomScale: Double,
        effectiveOffset: CGSize
    ) -> CGPoint {
        worldPoint.applying(
            affineTransform(
                viewportSize: viewportSize,
                zoomScale: zoomScale,
                effectiveOffset: effectiveOffset
            )
        )
    }

    /// Converts a world-space rectangle to a screen-space rectangle.
    /// - Parameters:
    ///   - worldRect: Rectangle in world-space coordinates.
    ///   - viewportSize: Current viewport size.
    ///   - zoomScale: Active zoom scale.
    ///   - effectiveOffset: Screen-space offset after camera and manual panning are combined.
    /// - Returns: Rectangle in screen-space coordinates.
    static func rectOnScreen(
        worldRect: CGRect,
        viewportSize: CGSize,
        zoomScale: Double,
        effectiveOffset: CGSize
    ) -> CGRect {
        let minPoint = pointOnScreen(
            worldPoint: CGPoint(x: worldRect.minX, y: worldRect.minY),
            viewportSize: viewportSize,
            zoomScale: zoomScale,
            effectiveOffset: effectiveOffset
        )
        let maxPoint = pointOnScreen(
            worldPoint: CGPoint(x: worldRect.maxX, y: worldRect.maxY),
            viewportSize: viewportSize,
            zoomScale: zoomScale,
            effectiveOffset: effectiveOffset
        )
        return CGRect(
            x: min(minPoint.x, maxPoint.x),
            y: min(minPoint.y, maxPoint.y),
            width: abs(maxPoint.x - minPoint.x),
            height: abs(maxPoint.y - minPoint.y)
        )
    }
}
