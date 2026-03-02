// Background: Keymap keys must be conditionally enabled by declarative rules.
// Responsibility: Provide a composable predicate model for execution/capture conditions.
public indirect enum KeymapExecutionCondition: Equatable, Sendable {
    /// Always enabled.
    case always
    /// Condition must satisfy all listed predicates.
    case all([KeymapExecutionCondition])
    /// Enable only when text input mode is off.
    case notTextEditing
    /// Enable only for the listed target kinds.
    case targetKinds(Set<KeymapSwitchTargetKindIntentVariant>)
    /// Enable only when current editing mode is in one of these values.
    case requiredModes(Set<CanvasEditingMode>)
    /// Disable when current editing mode is in one of these values.
    case disallowedModes(Set<CanvasEditingMode>)
    /// Enable only when focused node exists.
    case requiresFocusedNode
    /// Enable only when selected node/edge counts satisfy constraints.
    case requiresSelectionCount(KeymapExecutionSelectionCountCondition)
    /// Enable only when listed modals are active.
    case modalIn(Set<KeymapExecutionModalKind>)
    /// Enable only when listed modals are inactive.
    case modalOut(Set<KeymapExecutionModalKind>)
}

// Background: Selection predicates need a compact, explicit schema.
// Responsibility: Represent node/edge count requirements for command eligibility.
public struct KeymapExecutionSelectionCountCondition: Equatable, Sendable {
    /// Minimum selected nodes required.
    public let minNodeCount: Int?
    /// Maximum selected nodes allowed.
    public let maxNodeCount: Int?
    /// Minimum selected edges required.
    public let minEdgeCount: Int?
    /// Maximum selected edges allowed.
    public let maxEdgeCount: Int?

    /// Creates a count constraint for node / edge selection.
    /// - Parameters:
    ///   - minNodeCount: Minimum selected nodes required.
    ///   - maxNodeCount: Maximum selected nodes allowed.
    ///   - minEdgeCount: Minimum selected edges required.
    ///   - maxEdgeCount: Maximum selected edges allowed.
    public init(
        minNodeCount: Int? = nil,
        maxNodeCount: Int? = nil,
        minEdgeCount: Int? = nil,
        maxEdgeCount: Int? = nil
    ) {
        self.minNodeCount = minNodeCount
        self.maxNodeCount = maxNodeCount
        self.minEdgeCount = minEdgeCount
        self.maxEdgeCount = maxEdgeCount
    }

    func matches(nodeCount: Int, edgeCount: Int) -> Bool {
        if let minNodeCount {
            guard nodeCount >= minNodeCount else {
                return false
            }
        }
        if let maxNodeCount {
            guard nodeCount <= maxNodeCount else {
                return false
            }
        }
        if let minEdgeCount {
            guard edgeCount >= minEdgeCount else {
                return false
            }
        }
        if let maxEdgeCount {
            guard edgeCount <= maxEdgeCount else {
                return false
            }
        }
        return true
    }
}

// Background: Resolver needs explicit modal categories for declarative policy checks.
// Responsibility: Represent whether command execution depends on modal visibility.
public enum KeymapExecutionModalKind: Equatable, Sendable {
    case commandPalette
    case search
    case connectNodeSelection
    case addNodePopup
}
