// Background: Canvas viewport math needs a shared rectangle primitive independent from UI frameworks.
// Responsibility: Provide immutable rectangle geometry utilities in canvas coordinates.
/// Immutable rectangle used for canvas content and viewport calculations.
public struct CanvasRect: Equatable, Sendable {
    /// Left edge in canvas coordinates.
    public let minX: Double
    /// Top edge in canvas coordinates.
    public let minY: Double
    /// Width in canvas coordinates.
    public let width: Double
    /// Height in canvas coordinates.
    public let height: Double

    /// Right edge in canvas coordinates.
    public var maxX: Double {
        minX + width
    }

    /// Bottom edge in canvas coordinates.
    public var maxY: Double {
        minY + height
    }

    /// Creates an immutable rectangle.
    /// - Parameters:
    ///   - minX: Left edge in canvas coordinates.
    ///   - minY: Top edge in canvas coordinates.
    ///   - width: Width in canvas coordinates.
    ///   - height: Height in canvas coordinates.
    public init(minX: Double, minY: Double, width: Double, height: Double) {
        self.minX = minX
        self.minY = minY
        self.width = max(0, width)
        self.height = max(0, height)
    }

    /// Returns a rectangle expanded equally in all directions.
    /// - Parameters:
    ///   - horizontal: Horizontal expansion value.
    ///   - vertical: Vertical expansion value.
    /// - Returns: Expanded rectangle.
    public func expanded(horizontal: Double, vertical: Double) -> CanvasRect {
        let safeHorizontal = max(0, horizontal)
        let safeVertical = max(0, vertical)
        return CanvasRect(
            minX: minX - safeHorizontal,
            minY: minY - safeVertical,
            width: width + (safeHorizontal * 2),
            height: height + (safeVertical * 2)
        )
    }
}
