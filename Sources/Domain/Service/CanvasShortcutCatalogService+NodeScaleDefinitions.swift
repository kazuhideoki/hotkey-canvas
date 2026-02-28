// Background: Node scaling shortcuts use multiple keyboard-layout variants for plus input.
// Responsibility: Provide shortcut catalog entries for selected-node scaling commands.
extension CanvasShortcutCatalogService {
    static func nodeScaleDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "scaleSelectedNodesUp.commandOptionPlus"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Scale Up"),
                gesture: CanvasShortcutGesture(key: .character("+"), modifiers: [.command, .option]),
                action: .apply(commands: [.scaleSelectedNodes(.up)]),
                shortcutLabel: "⌘⌥+",
                searchTokens: ["node", "scale", "resize", "grow", "expand", "selected"],
                commandPaletteVisibility: .requiresFocusedNode
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "scaleSelectedNodesUp.commandOptionShiftSemicolon"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Scale Up"),
                gesture: CanvasShortcutGesture(key: .character(";"), modifiers: [.command, .option, .shift]),
                action: .apply(commands: [.scaleSelectedNodes(.up)]),
                shortcutLabel: "⌘⌥+",
                searchTokens: ["node", "scale", "resize", "grow", "expand", "selected"],
                commandPaletteVisibility: .requiresFocusedNode
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "scaleSelectedNodesUp.commandOptionShiftEquals"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Scale Up"),
                gesture: CanvasShortcutGesture(key: .character("="), modifiers: [.command, .option, .shift]),
                action: .apply(commands: [.scaleSelectedNodes(.up)]),
                shortcutLabel: "⌘⌥+",
                searchTokens: ["node", "scale", "resize", "grow", "expand", "selected"],
                commandPaletteVisibility: .requiresFocusedNode
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "scaleSelectedNodesUp.commandOptionEquals"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Scale Up"),
                gesture: CanvasShortcutGesture(key: .character("="), modifiers: [.command, .option]),
                action: .apply(commands: [.scaleSelectedNodes(.up)]),
                shortcutLabel: "⌘⌥=",
                searchTokens: ["node", "scale", "resize", "grow", "expand", "selected"],
                commandPaletteVisibility: .requiresFocusedNode
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "scaleSelectedNodesDown.commandOptionMinus"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Scale Down"),
                gesture: CanvasShortcutGesture(key: .character("-"), modifiers: [.command, .option]),
                action: .apply(commands: [.scaleSelectedNodes(.down)]),
                shortcutLabel: "⌘⌥-",
                searchTokens: ["node", "scale", "resize", "shrink", "contract", "selected"],
                commandPaletteVisibility: .requiresFocusedNode
            ),
        ]
    }
}
