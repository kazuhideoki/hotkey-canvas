// Background: Execution behavior differs by route, not by caller.
// Responsibility: Declare whether shortcut apply commands stay in normal flow
// or are routed through edge-target handlers when active.
public enum KeymapExecutionRoute: Equatable, Sendable {
    /// Apply via `viewModel.apply` directly.
    case direct
    /// Delegate to edge-target handlers while in `.edge`, otherwise apply directly.
    case edgeAware
}
