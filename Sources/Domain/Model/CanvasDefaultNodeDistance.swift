// Background: Canvas editing features need one shared source for default node-to-node distances.
// Responsibility: Define default horizontal/vertical distances used by tree and diagram operations.
/// Default distance definitions shared across canvas editing modes.
public enum CanvasDefaultNodeDistance {
    /// Default horizontal distance between connected nodes in tree mode.
    public static let treeHorizontal: Double = 32

    /// Default vertical distance for tree mode (keeps legacy behavior).
    public static let treeVertical: Double = 24

    /// Default square side length used by diagram nodes.
    public static let diagramNodeSide: Double = 220

    /// Default horizontal distance between diagram nodes.
    public static let diagramHorizontal: Double = diagramNodeSide

    /// Default vertical distance between diagram nodes.
    public static let diagramVertical: Double = diagramNodeSide

    /// Default vertical spacing between top-level tree roots.
    public static let treeRootVertical: Double = treeVertical * 2

    /// Backward-compatible alias for tree horizontal distance.
    public static let horizontal: Double = treeHorizontal

    /// Returns default vertical distance for a specific editing mode.
    /// - Parameter mode: Canvas editing mode.
    /// - Returns: Mode-specific default vertical distance.
    public static func vertical(for mode: CanvasEditingMode) -> Double {
        switch mode {
        case .tree:
            treeVertical
        case .diagram:
            diagramVertical
        }
    }
}
