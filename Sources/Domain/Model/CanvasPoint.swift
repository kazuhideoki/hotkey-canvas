// Background: Polygon-based area layout needs a framework-independent 2D point model.
// Responsibility: Represent immutable canvas coordinates for geometry calculations.
/// Immutable 2D point in canvas coordinates.
public struct CanvasPoint: Equatable, Hashable, Sendable {
    /// Horizontal coordinate.
    public let x: Double
    /// Vertical coordinate.
    public let y: Double

    /// Creates a point.
    /// - Parameters:
    ///   - x: Horizontal coordinate.
    ///   - y: Vertical coordinate.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
