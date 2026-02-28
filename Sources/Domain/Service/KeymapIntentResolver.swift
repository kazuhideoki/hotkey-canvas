// Background: Hotkey handling needs explicit scope routing before primitive intent resolution.
// Responsibility: Resolve gestures into primitive/global/modal route payloads.
/// Domain resolver for keymap routing.
public enum KeymapIntentResolver {
    /// Resolves a canonical gesture into route payload.
    /// - Parameter gesture: Canonical shortcut gesture from input adapter.
    /// - Returns: Route payload when gesture is supported.
    public static func resolveRoute(for gesture: CanvasShortcutGesture) -> KeymapResolvedRoute? {
        if let globalAction = globalAction(for: gesture) {
            return .global(action: globalAction)
        }

        guard let action = CanvasShortcutCatalogService.resolveAction(for: gesture) else {
            return nil
        }
        return primitiveRoute(for: action)
    }
}

extension KeymapIntentResolver {
    private static func globalAction(for gesture: CanvasShortcutGesture) -> KeymapGlobalAction? {
        if gesture
            == CanvasShortcutGesture(
                key: .character("f"),
                modifiers: [.command]
            )
        {
            return .openSearch
        }
        guard let action = CanvasShortcutCatalogService.resolveAction(for: gesture) else {
            return nil
        }
        switch action {
        case .openCommandPalette:
            return .openCommandPalette
        case .undo:
            return .undo
        case .redo:
            return .redo
        case .zoomIn:
            return .zoomIn
        case .zoomOut:
            return .zoomOut
        case .apply(let commands):
            return globalAction(for: commands)
        case .beginConnectNodeSelection:
            return nil
        }
    }

    private static func globalAction(for commands: [CanvasCommand]) -> KeymapGlobalAction? {
        guard commands.count == 1 else {
            return nil
        }
        switch commands[0] {
        case .centerFocusedNode:
            return .centerFocusedNode
        default:
            return nil
        }
    }

    private static func primitiveRoute(for action: CanvasShortcutAction) -> KeymapResolvedRoute? {
        switch action {
        case .beginConnectNodeSelection:
            return .primitive(intent: .switchTargetKind(variant: .edge))
        case .apply(let commands):
            guard let intent = primitiveIntent(for: commands) else {
                return nil
            }
            return .primitive(intent: intent)
        case .undo, .redo, .zoomIn, .zoomOut, .openCommandPalette:
            return nil
        }
    }

    private static func primitiveIntent(for commands: [CanvasCommand]) -> KeymapPrimitiveIntent? {
        guard commands.count == 1 else {
            return nil
        }
        let command = commands[0]
        return primitiveIntentFromNodeMutation(command)
            ?? primitiveIntentFromNavigation(command)
            ?? primitiveIntentFromReservedRoute(command)
    }

    private static func primitiveIntentFromNodeMutation(_ command: CanvasCommand) -> KeymapPrimitiveIntent? {
        switch command {
        case .addNode:
            return .add(variant: .modeSelect)
        case .addChildNode:
            return .add(variant: .hierarchical)
        case .addSiblingNode(position: .above):
            return .add(variant: .alternate)
        case .addSiblingNode(position: .below):
            return .add(variant: .primary)
        case .deleteFocusedNode:
            return .delete
        case .duplicateSelectionAsSibling:
            return .duplicate
        case .toggleFoldFocusedSubtree:
            return .toggleVisibility
        case .alignParentNodesVertically:
            return .edit
        default:
            return nil
        }
    }

    private static func primitiveIntentFromNavigation(_ command: CanvasCommand) -> KeymapPrimitiveIntent? {
        switch command {
        case .moveFocus:
            return .moveFocus(variant: .single)
        case .extendSelection:
            return .moveFocus(variant: .extendSelection)
        case .moveNode:
            return .moveNode
        case .nudgeNode:
            return .nudgeNode
        case .connectNodes:
            return .switchTargetKind(variant: .edge)
        case .convertFocusedAreaMode:
            return .transform
        default:
            return nil
        }
    }

    private static func primitiveIntentFromReservedRoute(_ command: CanvasCommand) -> KeymapPrimitiveIntent? {
        switch command {
        case .focusNode, .copyFocusedSubtree, .cutFocusedSubtree, .pasteSubtreeAsChild, .setNodeText,
                .upsertNodeAttachment, .toggleFocusedNodeMarkdownStyle, .centerFocusedNode, .createArea,
                .assignNodesToArea:
            return nil
        default:
            return nil
        }
    }
}
