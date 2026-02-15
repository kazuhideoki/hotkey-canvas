import Domain
import Foundation

// Background: The canvas view requires a dynamic drawable area that grows with node placement.
// Responsibility: Calculate a stable content rectangle for rendering and scrolling.
/// Computes renderable canvas content bounds from current node positions.
public enum CanvasContentBoundsCalculator {
    /// Calculates content bounds with minimum size constraints and outer margin.
    /// Steps:
    /// 1. Compute the bounding rectangle from all node bounds (min/max edges).
    /// 2. Expand the rectangle by `margin` on all sides.
    /// 3. If needed, enlarge to `minimumWidth`/`minimumHeight` with centered padding.
    /// - Parameters:
    ///   - nodes: Nodes placed on the canvas.
    ///   - minimumWidth: Minimum drawable width.
    ///   - minimumHeight: Minimum drawable height.
    ///   - margin: Extra space reserved around the outermost nodes.
    /// - Returns: Content rectangle used by the view layer for scrolling and rendering.
    public static func calculate(
        nodes: [CanvasNode],
        minimumWidth: Double,
        minimumHeight: Double,
        margin: Double
    ) -> CanvasRect {
        let clampedMinimumWidth = max(0, minimumWidth)
        let clampedMinimumHeight = max(0, minimumHeight)
        let clampedMargin = max(0, margin)

        guard let firstNode = nodes.first else {
            return CanvasRect(
                minX: 0,
                minY: 0,
                width: clampedMinimumWidth,
                height: clampedMinimumHeight
            )
        }

        var minX = firstNode.bounds.x
        var minY = firstNode.bounds.y
        var maxX = firstNode.bounds.x + firstNode.bounds.width
        var maxY = firstNode.bounds.y + firstNode.bounds.height

        for node in nodes.dropFirst() {
            minX = min(minX, node.bounds.x)
            minY = min(minY, node.bounds.y)
            maxX = max(maxX, node.bounds.x + node.bounds.width)
            maxY = max(maxY, node.bounds.y + node.bounds.height)
        }

        let expanded = CanvasRect(
            minX: minX,
            minY: minY,
            width: maxX - minX,
            height: maxY - minY
        )
        .expanded(horizontal: clampedMargin, vertical: clampedMargin)

        let adjustedWidth = max(expanded.width, clampedMinimumWidth)
        let adjustedHeight = max(expanded.height, clampedMinimumHeight)
        let horizontalPadding = (adjustedWidth - expanded.width) / 2
        let verticalPadding = (adjustedHeight - expanded.height) / 2

        return CanvasRect(
            minX: expanded.minX - horizontalPadding,
            minY: expanded.minY - verticalPadding,
            width: adjustedWidth,
            height: adjustedHeight
        )
    }
}
