// Background: Mixed canvas editing needs explicit per-area semantics.
// Responsibility: Define editing behavior mode for each canvas area.
/// Editing mode assigned to one canvas area.
public enum CanvasEditingMode: Equatable, Sendable {
    case tree
    case diagram
}
