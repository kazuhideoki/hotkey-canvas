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
            return .apply(commands: [.deleteFocusedNode])
        case .toggleVisibility:
            return .apply(commands: [.toggleFoldFocusedSubtree])
        case .duplicate:
            return .apply(commands: [.duplicateSelectionAsSibling])
        case .attach:
            return .reportUnsupportedIntent(intent: primitiveIntent)
        case .switchTargetKind(let variant):
            return resolveSwitchTargetKindContextAction(variant: variant, primitiveIntent: primitiveIntent)
        case .moveFocus(let direction, let variant):
            return resolveMoveFocusContextAction(direction: direction, variant: variant)
        case .moveNode(let direction):
            return .apply(commands: [.moveNode(direction)])
        case .nudgeNode(let direction):
            return .apply(commands: [.nudgeNode(direction)])
        case .transform, .output, .export, .import:
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
        case .alignParentNodesVertically:
            return .apply(commands: [.alignParentNodesVertically])
        case .copySubtree:
            return .apply(commands: [.copyFocusedSubtree])
        case .cutSubtree:
            return .apply(commands: [.cutFocusedSubtree])
        case .pasteSubtreeAsChild:
            return .apply(commands: [.pasteSubtreeAsChild])
        }
    }

    private func resolveSwitchTargetKindContextAction(
        variant: KeymapSwitchTargetKindIntentVariant,
        primitiveIntent: KeymapPrimitiveIntent
    ) -> KeymapContextAction {
        switch variant {
        case .edge:
            return .beginConnectNodeSelection
        case .node:
            return .reportUnsupportedIntent(intent: primitiveIntent)
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
}
