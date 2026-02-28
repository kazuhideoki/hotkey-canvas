// Background: Command palette visibility depends on current focus availability and active editing mode.
// Responsibility: Provide filtering context used by shortcut catalog when building palette items.
/// Runtime context used to filter command palette entries.
public struct CanvasCommandPaletteContext: Equatable, Sendable {
    /// Active editing mode inferred from focus or deterministic canvas state.
    public let activeEditingMode: CanvasEditingMode?
    /// Whether there is currently a focused node.
    public let hasFocusedNode: Bool

    /// Creates a command palette filtering context.
    /// - Parameters:
    ///   - activeEditingMode: Active mode if deterministically known.
    ///   - hasFocusedNode: Focus presence used for focus-required commands.
    public init(activeEditingMode: CanvasEditingMode?, hasFocusedNode: Bool) {
        self.activeEditingMode = activeEditingMode
        self.hasFocusedNode = hasFocusedNode
    }
}
