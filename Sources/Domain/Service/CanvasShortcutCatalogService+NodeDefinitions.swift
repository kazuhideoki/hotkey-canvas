// Background: Node editing shortcuts are maintained as one group but are easier to review in smaller definitions.
// Responsibility: Build node-oriented shortcut catalog entries.
extension CanvasShortcutCatalogService {
    static func nodeEditingDefinitions() -> [CanvasShortcutDefinition] {
        baseNodeCreationDefinitions() + baseNodeMutationDefinitions() + clipboardNodeEditingDefinitions()
    }

    private static func baseNodeCreationDefinitions() -> [CanvasShortcutDefinition] {
        [
            addChildNodeDefinition(),
            addNodeDefinition(),
        ] + siblingNodeCreationDefinitions()
    }

    private static func addChildNodeDefinition() -> CanvasShortcutDefinition {
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
        )
    }

    private static func addNodeDefinition() -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "addNode"),
            commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Add"),
            gesture: CanvasShortcutGesture(key: .enter, modifiers: [.shift]),
            action: .apply(commands: [.addNode]),
            shortcutLabel: shortcutLabel(
                for: CanvasShortcutGesture(key: .enter, modifiers: [.shift])
            ),
            executionCondition: nodeTargetCondition()
        )
    }

    private static func siblingNodeCreationDefinitions() -> [CanvasShortcutDefinition] {
        [
            siblingNodeCreationDefinition(position: .above, keyModifiers: [.option], verb: "Add Sibling Above"),
            siblingNodeCreationDefinition(position: .below, keyModifiers: [], verb: "Add Sibling Below"),
        ]
    }

    private static func siblingNodeCreationDefinition(
        position: CanvasSiblingNodePosition,
        keyModifiers: CanvasShortcutModifiers,
        verb: String
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: position == .above ? "addSiblingNodeAbove" : "addSiblingNodeBelow"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Node",
                verb: verb
            ),
            gesture: CanvasShortcutGesture(key: .enter, modifiers: keyModifiers),
            action: .apply(commands: [.addSiblingNode(position: position)]),
            shortcutLabel: shortcutLabel(
                for: CanvasShortcutGesture(key: .enter, modifiers: keyModifiers)
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

    private static func baseNodeMutationDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "deleteSelectedOrFocusedNodes"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Delete Selected"),
                gesture: CanvasShortcutGesture(key: .deleteBackward, modifiers: []),
                action: .apply(commands: [.deleteSelectedOrFocusedNodes]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .deleteBackward, modifiers: [])
                ),
                commandPaletteVisibility: .requiresFocusedNode,
                executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNode),
                executionRoute: .edgeAware
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "duplicateSelectionAsSibling"),
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Node",
                    verb: "Duplicate Selection As Sibling"
                ),
                gesture: CanvasShortcutGesture(key: .character("d"), modifiers: [.command]),
                action: .apply(commands: [.duplicateSelectionAsSibling]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("d"), modifiers: [.command])
                ),
                searchTokens: ["duplicate", "selection", "sibling", "tree"],
                commandPaletteVisibility: .requiresFocusedNodeAndMode([.tree]),
                executionCondition: nodeTargetCondition(
                    combinedWith: .all([
                        .requiresFocusedNode,
                        .requiredModes([.tree]),
                    ])
                )
            ),
        ]
    }

    private static func clipboardNodeEditingDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "copySelectionOrFocusedSubtree"),
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Node",
                    verb: "Copy Selected"
                ),
                gesture: CanvasShortcutGesture(key: .character("c"), modifiers: [.command]),
                action: .apply(commands: [.copySelectionOrFocusedSubtree]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("c"), modifiers: [.command])
                ),
                searchTokens: ["copy", "selected", "subtree", "node"],
                commandPaletteVisibility: .requiresFocusedNode,
                executionCondition: nodeExecutionCondition(for: .requiresFocusedNode)
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "cutSelectionOrFocusedSubtree"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Cut Selected"),
                gesture: CanvasShortcutGesture(key: .character("x"), modifiers: [.command]),
                action: .apply(commands: [.cutSelectionOrFocusedSubtree]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("x"), modifiers: [.command])
                ),
                searchTokens: ["cut", "selected", "subtree", "node"],
                commandPaletteVisibility: .requiresFocusedNode,
                executionCondition: nodeExecutionCondition(for: .requiresFocusedNode)
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "pasteClipboardAtFocusedNode"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Paste"),
                gesture: CanvasShortcutGesture(key: .character("v"), modifiers: [.command]),
                action: .apply(commands: [.pasteClipboardAtFocusedNode]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("v"), modifiers: [.command])
                ),
                searchTokens: ["paste", "selected", "subtree", "child", "node"],
                commandPaletteVisibility: .requiresFocusedNode,
                executionCondition: nodeExecutionCondition(for: .requiresFocusedNode)
            ),
        ]
    }
}
