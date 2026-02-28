// Background: Canvas editing features need one shared source for default node-to-node distances.
// Responsibility: Define default horizontal/vertical distances used by tree and diagram operations.
/// Default distance definitions shared across canvas editing modes.
public enum CanvasDefaultNodeDistance {
    /// Default node width for text nodes in tree mode.
    public static let treeNodeWidth: Double = 220

    /// Default node height for text nodes in tree mode.
    public static let treeNodeHeight: Double = 41

    /// Default horizontal distance between connected nodes in tree mode.
    public static let treeHorizontal: Double = 32

    /// Default vertical distance for tree mode (keeps legacy behavior).
    public static let treeVertical: Double = 24

    /// Default square side length used by diagram nodes.
    public static let diagramNodeSide: Double = 220

    /// Maximum square side length allowed for diagram nodes with image attachments.
    public static let diagramImageMaxSide: Double = diagramNodeSide * 1.5

    /// Minimum square side length allowed for diagram nodes.
    public static let diagramMinNodeSide: Double = diagramNodeSide * 0.5

    /// One-step ratio used for node scaling.
    public static let nodeScaleStepRatio: Double = 0.1

    /// Minimum width ratio used when scaling tree nodes.
    public static let treeNodeMinimumWidthRatio: Double = 0.5

    /// Minimum height ratio used when scaling tree nodes.
    public static let treeNodeMinimumHeightRatio: Double = 0.5

    /// Default horizontal distance between diagram nodes.
    public static let diagramHorizontal: Double = diagramNodeSide

    /// Default vertical distance between diagram nodes.
    public static let diagramVertical: Double = diagramNodeSide

    /// Default vertical spacing between top-level tree roots.
    public static let treeRootVertical: Double = treeVertical * 2

    /// Step multiplier for diagram semantic move (`cmd + arrow`).
    public static let diagramMoveStepMultiplier: Double = 1

    /// Step multiplier for diagram nudge (`cmd + shift + arrow`).
    /// Keep this as one quarter of semantic move to preserve a 4:1 ratio.
    public static let diagramNudgeStepMultiplier: Double = 0.25

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
