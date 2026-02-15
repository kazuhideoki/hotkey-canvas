// Background: Layout algorithms need an explicit value object for accumulated movement.
// Responsibility: Represent immutable 2D translation in canvas coordinates.
/// Immutable translation offset in canvas coordinates.
public struct CanvasTranslation: Equatable, Sendable {
    /// Horizontal translation amount.
    public let dx: Double
    /// Vertical translation amount.
    public let dy: Double

    /// Zero translation.
    public static let zero = CanvasTranslation(dx: 0, dy: 0)

    /// Returns whether both axes have no translation.
    public var isZero: Bool {
        dx == 0 && dy == 0
    }

    /// Creates a translation value.
    /// - Parameters:
    ///   - dx: Horizontal translation amount.
    ///   - dy: Vertical translation amount.
    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }
}
