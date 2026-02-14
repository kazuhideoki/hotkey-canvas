// Background: Node layout data must remain independent from UI framework types.
// Responsibility: Hold immutable rectangular bounds for a canvas node.
/// Immutable rectangle used to position and size a canvas node.
public struct CanvasBounds: Equatable, Sendable {
    /// Horizontal origin in canvas coordinates.
    public let x: Double
    /// Vertical origin in canvas coordinates.
    public let y: Double
    /// Width in canvas coordinates.
    public let width: Double
    /// Height in canvas coordinates.
    public let height: Double

    /// Creates immutable bounds.
    /// - Parameters:
    ///   - x: Horizontal origin.
    ///   - y: Vertical origin.
    ///   - width: Rectangle width.
    ///   - height: Rectangle height.
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
