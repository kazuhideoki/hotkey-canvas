// Background: Node creation shortcuts carry focused-node and mode gating rules.
// Responsibility: Provide canonical shortcut definitions for node creation commands.
extension CanvasShortcutCatalogService {
    static func baseNodeCreationDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addChildNode"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Add Child"),
                gesture: CanvasShortcutGesture(key: .enter, modifiers: [.command]),
                action: .apply(commands: [.addChildNode]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .enter, modifiers: [.command])
                ),
                commandPaletteVisibility: .requiresFocusedNodeAndMode([.tree]),
                executionCondition: nodeTargetCondition()
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addNode"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Add"),
                gesture: CanvasShortcutGesture(key: .enter, modifiers: [.shift]),
                action: .apply(commands: [.addNode]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .enter, modifiers: [.shift])
                ),
                executionCondition: nodeTargetCondition()
            ),
            addSiblingNodeCreationDefinition(
                id: "addSiblingNodeAbove",
                verb: "Add Sibling Above",
                modifiers: [.option],
                position: .above
            ),
            addSiblingNodeCreationDefinition(
                id: "addSiblingNodeBelow",
                verb: "Add Sibling Below",
                modifiers: [],
                position: .below
            ),
        ]
    }

    private static func addSiblingNodeCreationDefinition(
        id: String,
        verb: String,
        modifiers: CanvasShortcutModifiers,
        position: CanvasSiblingNodePosition
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: id),
            commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: verb),
            gesture: CanvasShortcutGesture(key: .enter, modifiers: modifiers),
            action: .apply(commands: [.addSiblingNode(position: position)]),
            shortcutLabel: shortcutLabel(
                for: CanvasShortcutGesture(key: .enter, modifiers: modifiers)
            ),
            commandPaletteVisibility: .requiresFocusedNodeAndMode([.tree]),
            executionCondition: nodeTargetCondition(
                combinedWith: .all([
                    .requiresFocusedNode,
                    .requiredModes([.tree]),
                ])
            )
        )
    }
}
