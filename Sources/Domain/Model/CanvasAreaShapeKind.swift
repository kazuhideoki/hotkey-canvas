// Background: Area extraction needs a stable strategy selector to choose shape construction.
// Responsibility: Enumerate supported shape generation strategies.
/// Shape generation strategy used when constructing `CanvasNodeArea`.
public enum CanvasAreaShapeKind: Equatable, Sendable {
    /// Use axis-aligned rectangle bounds.
    case rectangle
    /// Use convex hull from node rectangle corners.
    case convexHull
}
