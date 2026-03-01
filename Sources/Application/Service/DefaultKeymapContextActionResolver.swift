// Background: Primitive intent routing needs an application-level bridge into executable behavior.
// Responsibility: Convert primitive intents into concrete context actions without UI/framework dependencies.
import Domain

/// Default resolver from primitive keymap intent to executable context action.
public struct DefaultKeymapContextActionResolver: KeymapContextActionResolver {
    public init() {}

    public func resolve(primitiveIntent: KeymapPrimitiveIntent) -> KeymapContextAction {
        switch primitiveIntent {
        case .add(let variant):
            return resolveAddContextAction(variant: variant)
        case .edit(let variant):
            return resolveEditContextAction(variant: variant)
        case .delete:
            return .apply(commands: [.deleteSelectedOrFocusedNodes])
        case .toggleVisibility:
            return .apply(commands: [.toggleFoldFocusedSubtree])
        case .duplicate:
            return .apply(commands: [.duplicateSelectionAsSibling])
        case .attach:
            return .reportUnsupportedIntent(intent: primitiveIntent)
        case .switchTargetKind(let variant):
            return resolveSwitchTargetKindContextAction(variant: variant)
        case .cycleFocusedEdgeDirectionality:
            return .cycleFocusedEdgeDirectionality
        case .moveFocus(let direction, let variant):
            return resolveMoveFocusContextAction(direction: direction, variant: variant)
        case .moveNode(let direction):
            return .apply(commands: [.moveNode(direction)])
        case .nudgeNode(let direction):
            return .apply(commands: [.nudgeNode(direction)])
        case .transform(let variant):
            return resolveTransformContextAction(variant: variant, primitiveIntent: primitiveIntent)
        case .output, .export, .import:
            return .reportUnsupportedIntent(intent: primitiveIntent)
        }
    }
}

extension DefaultKeymapContextActionResolver {
    private func resolveAddContextAction(variant: KeymapAddIntentVariant) -> KeymapContextAction {
        switch variant {
        case .primary:
            return .apply(commands: [.addSiblingNode(position: .below)])
        case .alternate:
            return .apply(commands: [.addSiblingNode(position: .above)])
        case .hierarchical:
            return .apply(commands: [.addChildNode])
        case .modeSelect:
            return .presentAddNodeModeSelection
        }
    }

    private func resolveEditContextAction(variant: KeymapEditIntentVariant) -> KeymapContextAction {
        switch variant {
        case .alignAllAreasVertically:
            return .apply(commands: [.alignAllAreasVertically])
        case .copySelectionOrFocusedSubtree:
            return .apply(commands: [.copySelectionOrFocusedSubtree])
        case .cutSelectionOrFocusedSubtree:
            return .apply(commands: [.cutSelectionOrFocusedSubtree])
        case .pasteClipboardAtFocusedNode:
            return .apply(commands: [.pasteClipboardAtFocusedNode])
        }
    }

    private func resolveSwitchTargetKindContextAction(
        variant: KeymapSwitchTargetKindIntentVariant
    ) -> KeymapContextAction {
        switch variant {
        case .edge:
            return .switchTargetKind(variant: .edge)
        case .node:
            return .switchTargetKind(variant: .node)
        }
    }

    private func resolveMoveFocusContextAction(
        direction: CanvasFocusDirection,
        variant: KeymapMoveFocusIntentVariant
    ) -> KeymapContextAction {
        switch variant {
        case .single:
            return .apply(commands: [.moveFocus(direction)])
        case .extendSelection:
            return .apply(commands: [.extendSelection(direction)])
        }
    }

    private func resolveTransformContextAction(
        variant: KeymapTransformIntentVariant,
        primitiveIntent: KeymapPrimitiveIntent
    ) -> KeymapContextAction {
        switch variant {
        case .scaleSelectionUp:
            return .apply(commands: [.scaleSelectedNodes(.up)])
        case .scaleSelectionDown:
            return .apply(commands: [.scaleSelectedNodes(.down)])
        case .convertFocusedAreaMode:
            return .reportUnsupportedIntent(intent: primitiveIntent)
        }
    }
}
