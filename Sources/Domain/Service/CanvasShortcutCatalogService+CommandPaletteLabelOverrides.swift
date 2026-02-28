// Background: Command palette labels should remain simple while reflecting mode-specific behavior differences.
// Responsibility: Provide context-based label overrides without changing shortcut execution semantics.
extension CanvasShortcutCatalogService {
    static func commandPaletteDefinition(
        _ definition: CanvasShortcutDefinition,
        for context: CanvasCommandPaletteContext
    ) -> CanvasShortcutDefinition {
        guard let label = commandPaletteLabel(for: definition.id, context: context) else {
            return definition
        }
        return CanvasShortcutDefinition(
            id: definition.id,
            commandPaletteLabel: label,
            gesture: definition.gesture,
            action: definition.action,
            shortcutLabel: definition.shortcutLabel,
            searchTokens: definition.searchTokens,
            isVisibleInCommandPalette: definition.isVisibleInCommandPalette,
            commandPaletteVisibility: definition.commandPaletteVisibility
        )
    }

    static func commandPaletteLabel(
        for shortcutID: CanvasShortcutID,
        context: CanvasCommandPaletteContext
    ) -> CanvasCommandPaletteLabel? {
        switch context.activeEditingMode {
        case .tree:
            switch shortcutID.rawValue {
            case "copyFocusedSubtree":
                return CanvasCommandPaletteLabel(noun: "Node", verb: "Copy Selected & Subtree")
            case "cutFocusedSubtree":
                return CanvasCommandPaletteLabel(noun: "Node", verb: "Cut Selected & Subtree")
            case "pasteSubtreeAsChild":
                return CanvasCommandPaletteLabel(noun: "Node", verb: "Paste As Child")
            default:
                return nil
            }
        case .diagram:
            switch shortcutID.rawValue {
            case "copyFocusedSubtree":
                return CanvasCommandPaletteLabel(noun: "Node", verb: "Copy Selected")
            case "cutFocusedSubtree":
                return CanvasCommandPaletteLabel(noun: "Node", verb: "Cut Selected")
            case "pasteSubtreeAsChild":
                return CanvasCommandPaletteLabel(noun: "Node", verb: "Paste")
            default:
                return nil
            }
        case nil:
            return nil
        }
    }
}
