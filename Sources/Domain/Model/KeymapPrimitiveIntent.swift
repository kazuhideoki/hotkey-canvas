// Background: Primitive hotkeys must be represented by abstract intent instead of direct command wiring.
// Responsibility: Define primitive intent vocabulary and variant dimensions.
/// Intent variant for add-like primitive actions.
public enum KeymapAddIntentVariant: Equatable, Sendable {
    case primary
    case alternate
    case hierarchical
    case modeSelect
}

/// Intent variant for focus movement behaviors.
public enum KeymapMoveFocusIntentVariant: Equatable, Sendable {
    case single
    case extendSelection
}

/// Intent variant for switching operation target kind.
public enum KeymapSwitchTargetKindIntentVariant: Equatable, Sendable {
    case node
    case edge
}

/// Primitive intent resolved from shortcut input.
public enum KeymapPrimitiveIntent: Equatable, Sendable {
    case add(variant: KeymapAddIntentVariant)
    case edit
    case delete
    case toggleVisibility
    case duplicate
    case attach
    case switchTargetKind(variant: KeymapSwitchTargetKindIntentVariant)
    case moveFocus(variant: KeymapMoveFocusIntentVariant)
    case moveNode
    case nudgeNode
    case transform
    case output
    case export
    case `import`
}
