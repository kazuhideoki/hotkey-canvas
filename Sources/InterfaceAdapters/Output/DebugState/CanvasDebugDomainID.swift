// Background: Debug APIs expose domain slices using stable identifiers for external tooling.
// Responsibility: Define versioned domain identifiers and labels for debug-state endpoints.
import Foundation

/// Stable identifiers for domain-state debug snapshots.
public enum CanvasDebugDomainID: String, CaseIterable, Sendable {
    case d1CanvasGraphEditing = "d1-canvas-graph-editing"
    case d2FocusAndSelection = "d2-focus-and-selection"
    case d3AreaLayout = "d3-area-layout"
    case d4TreeLayout = "d4-tree-layout"
    case d5ShortcutCatalog = "d5-shortcut-catalog"
    case d6FoldVisibility = "d6-fold-visibility"
    case d7AreaModeMembership = "d7-area-mode-membership"

    /// Human-readable domain label.
    public var displayName: String {
        switch self {
        case .d1CanvasGraphEditing:
            return "Canvas Graph Editing"
        case .d2FocusAndSelection:
            return "Focus And Selection"
        case .d3AreaLayout:
            return "Area Layout"
        case .d4TreeLayout:
            return "Tree Layout"
        case .d5ShortcutCatalog:
            return "Shortcut Catalog"
        case .d6FoldVisibility:
            return "Fold Visibility"
        case .d7AreaModeMembership:
            return "Area Mode Membership"
        }
    }
}
