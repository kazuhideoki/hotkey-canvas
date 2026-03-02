// Background: Multiple layers need a single truth for keymap eligibility.
// Responsibility: Evaluate declarative conditions against execution context snapshots.
public enum KeymapExecutionPolicyResolver {
    /// Evaluates command definition condition against execution context.
    /// - Parameters:
    ///   - definition: Shortcut definition with attached execution condition.
    ///   - context: Runtime execution context.
    /// - Returns: Whether command can be executed/captured.
    public static func isEnabled(
        definition: CanvasShortcutDefinition,
        context: KeymapExecutionContext
    ) -> Bool {
        isEnabled(definition.executionCondition, context: context)
    }

    /// Evaluates generic execution condition against context.
    /// - Parameters:
    ///   - condition: Declarative condition.
    ///   - context: Runtime execution context.
    /// - Returns: Whether condition is satisfied.
    public static func isEnabled(
        _ condition: KeymapExecutionCondition,
        context: KeymapExecutionContext
    ) -> Bool {
        switch condition {
        case .always:
            return true
        case .all(let conditions):
            return conditions.allSatisfy { isEnabled($0, context: context) }
        case .notTextEditing:
            return !context.isEditingText
        case .targetKinds(let allowedKinds):
            return allowedKinds.contains(context.operationTargetKind)
        case .requiredModes(let allowedModes):
            guard let editingMode = context.editingMode else {
                return false
            }
            return allowedModes.contains(editingMode)
        case .disallowedModes(let forbiddenModes):
            guard let editingMode = context.editingMode else {
                return true
            }
            return !forbiddenModes.contains(editingMode)
        case .requiresFocusedNode:
            return context.hasFocusedNode
        case .requiresSelectionCount(let countCondition):
            return countCondition.matches(
                nodeCount: context.selectedNodeCount,
                edgeCount: context.selectedEdgeCount
            )
        case .modalIn(let modals):
            return modals.allSatisfy { context.isActive(modal: $0) }
        case .modalOut(let modals):
            return modals.allSatisfy { !context.isActive(modal: $0) }
        }
    }
}
