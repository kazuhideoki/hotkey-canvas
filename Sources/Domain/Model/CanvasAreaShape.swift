// Background: Area layout now supports multiple outer-shape strategies per node cluster.
// Responsibility: Define selectable area shapes used by collision checks.
/// Area outer shape used for overlap checks.
public enum CanvasAreaShape: Equatable, Sendable {
    /// Axis-aligned rectangle based on area bounds.
    case rectangle
    /// Convex hull generated from all node rectangle corners in the area.
    case convexHull(vertices: [CanvasPoint])
}
