// Background: Hotkey event handling and command-palette listing must share one shortcut source.
// Responsibility: Provide the canonical static shortcut catalog and gesture-to-action resolution.
/// Domain service that owns shortcut definitions and lookup logic.
public enum CanvasShortcutCatalogService {
    /// Resolves shortcut action for a gesture.
    /// - Parameter gesture: Canonical gesture from input adapter.
    /// - Returns: Matched action when registered.
    public static func resolveAction(for gesture: CanvasShortcutGesture) -> CanvasShortcutAction? {
        definitionsByGesture[gesture]
    }
    /// Returns command-palette visible shortcuts.
    /// - Returns: Shortcut entries visible to command palette UI.
    public static func commandPaletteDefinitions() -> [CanvasShortcutDefinition] {
        defaultDefinitionsStorage.filter(\.isVisibleInCommandPalette)
    }
    /// Returns command-palette visible shortcuts for a runtime context.
    /// - Parameters:
    ///   - context: Runtime context used for label adaptation.
    ///   - executionContext: Runtime context used for execution-policy filtering.
    /// - Returns: Shortcut entries visible to command palette UI.
    public static func commandPaletteDefinitions(
        context: CanvasCommandPaletteContext,
        executionContext: KeymapExecutionContext
    ) -> [CanvasShortcutDefinition] {
        defaultDefinitionsStorage.compactMap { definition in
            guard
                definition.isVisibleInCommandPalette,
                KeymapExecutionPolicyResolver.isEnabled(
                    definition: definition,
                    context: executionContext
                )
            else {
                return nil
            }
            return commandPaletteDefinition(definition, for: context)
        }
    }

    public static func definition(for action: CanvasShortcutAction) -> CanvasShortcutDefinition? {
        defaultDefinitionsStorage.first { $0.action == action }
    }

    public static func definition(for command: CanvasCommand) -> CanvasShortcutDefinition? {
        defaultDefinitionsStorage.first {
            guard case .apply(let commands) = $0.action else {
                return false
            }
            return commands.contains(where: { $0 == command })
        }
    }
}

extension CanvasShortcutCatalogService {
    static func nodeTargetCondition() -> KeymapExecutionCondition {
        .targetKinds([.node])
    }

    static func nodeTargetCondition(
        combinedWith condition: KeymapExecutionCondition
    ) -> KeymapExecutionCondition {
        .all([nodeTargetCondition(), condition])
    }

    static func nodeOrEdgeTargetCondition() -> KeymapExecutionCondition {
        .targetKinds([.node, .edge])
    }

    static func nodeOrEdgeTargetCondition(
        combinedWith condition: KeymapExecutionCondition
    ) -> KeymapExecutionCondition {
        .all([nodeOrEdgeTargetCondition(), condition])
    }

    static func nodeOrEdgeExecutionCondition(
        for visibility: CanvasCommandPaletteVisibility
    ) -> KeymapExecutionCondition {
        nodeOrEdgeTargetCondition(combinedWith: visibility.defaultExecutionCondition)
    }

    static func nodeExecutionCondition(
        for visibility: CanvasCommandPaletteVisibility
    ) -> KeymapExecutionCondition {
        nodeTargetCondition(combinedWith: visibility.defaultExecutionCondition)
    }
}

extension CanvasShortcutCatalogService {
    private static let defaultDefinitionsStorage: [CanvasShortcutDefinition] = makeDefaultDefinitions()

    private static let definitionsByGesture: [CanvasShortcutGesture: CanvasShortcutAction] = {
        Dictionary(uniqueKeysWithValues: defaultDefinitionsStorage.map { ($0.gesture, $0.action) })
    }()
    private static func makeDefaultDefinitions() -> [CanvasShortcutDefinition] {
        commandPaletteTriggerDefinitions()
            + nodeEditingDefinitions()
            + navigationDefinitions()
            + zoomDefinitions()
            + historyDefinitions()
    }

    private static func commandPaletteTriggerDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "openCommandPalette.commandK"),
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Palette",
                    verb: "Open Command"
                ),
                gesture: CanvasShortcutGesture(key: .character("k"), modifiers: [.command]),
                action: .openCommandPalette,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("k"), modifiers: [.command])
                ),
                searchTokens: ["palette", "command"],
                isVisibleInCommandPalette: false
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "openCommandPalette.commandShiftP"),
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Palette",
                    verb: "Open Command"
                ),
                gesture: CanvasShortcutGesture(key: .character("p"), modifiers: [.command, .shift]),
                action: .openCommandPalette,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("p"), modifiers: [.command, .shift])
                ),
                searchTokens: ["palette", "command"],
                isVisibleInCommandPalette: false
            ),
        ]
    }

<<<<<<< HEAD
    private static func nodeEditingDefinitions() -> [CanvasShortcutDefinition] {
        baseNodeCreationDefinitions() + baseNodeMutationDefinitions() + clipboardNodeEditingDefinitions()
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

=======
>>>>>>> main
    private static func navigationDefinitions() -> [CanvasShortcutDefinition] {
        focusNavigationDefinitions()
            + nodeNavigationDefinitions()
            + canvasNavigationDefinitions()
    }

    private static func focusNavigationDefinitions() -> [CanvasShortcutDefinition] {
        focusMoveDefinitions() + focusExtendDefinitions() + focusMoveAcrossAreasDefinitions()
    }

    private static func focusMoveDefinitions() -> [CanvasShortcutDefinition] {
        [
            focusMoveDefinition(direction: .down, key: .arrowDown),
            focusMoveDefinition(direction: .left, key: .arrowLeft),
            focusMoveDefinition(direction: .right, key: .arrowRight),
            focusMoveDefinition(direction: .up, key: .arrowUp),
        ]
    }

    private static func focusExtendDefinitions() -> [CanvasShortcutDefinition] {
        [
            focusExtendDefinition(direction: .down, key: .arrowDown),
            focusExtendDefinition(direction: .left, key: .arrowLeft),
            focusExtendDefinition(direction: .right, key: .arrowRight),
            focusExtendDefinition(direction: .up, key: .arrowUp),
        ]
    }

    private static func focusMoveDefinition(
        direction: CanvasFocusDirection,
        key: CanvasShortcutKey
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "moveFocus\(focusDirectionIDSuffix(direction))"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Focus",
                verb: "Move \(focusDirectionLabel(direction))"
            ),
            gesture: CanvasShortcutGesture(key: key, modifiers: []),
            action: .apply(commands: [.moveFocus(direction)]),
            shortcutLabel: shortcutLabel(for: CanvasShortcutGesture(key: key, modifiers: [])),
            commandPaletteVisibility: .requiresFocusedNode,
            executionRoute: .edgeAware
        )
    }

    private static func focusExtendDefinition(
        direction: CanvasFocusDirection,
        key: CanvasShortcutKey
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "extendSelection\(focusDirectionIDSuffix(direction))"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Selection",
                verb: "Extend \(focusDirectionLabel(direction))"
            ),
            gesture: CanvasShortcutGesture(key: key, modifiers: [.shift]),
            action: .apply(commands: [.extendSelection(direction)]),
            shortcutLabel: shortcutLabel(for: CanvasShortcutGesture(key: key, modifiers: [.shift])),
            commandPaletteVisibility: .requiresFocusedNode,
            executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNode),
            executionRoute: .edgeAware
        )
    }

    private static func nodeNavigationDefinitions() -> [CanvasShortcutDefinition] {
        nodeMoveDefinitions() + nodeNudgeDefinitions() + nodeScaleDefinitions()
    }

    private static func nodeMoveDefinitions() -> [CanvasShortcutDefinition] {
        [
            nodeMoveDefinition(direction: .down, key: .arrowDown),
            nodeMoveDefinition(direction: .left, key: .arrowLeft),
            nodeMoveDefinition(direction: .right, key: .arrowRight),
            nodeMoveDefinition(direction: .up, key: .arrowUp),
        ]
    }

    private static func nodeNudgeDefinitions() -> [CanvasShortcutDefinition] {
        [
            nodeNudgeDefinition(direction: .down, key: .arrowDown),
            nodeNudgeDefinition(direction: .left, key: .arrowLeft),
            nodeNudgeDefinition(direction: .right, key: .arrowRight),
            nodeNudgeDefinition(direction: .up, key: .arrowUp),
        ]
    }

    private static func nodeMoveDefinition(
        direction: CanvasNodeMoveDirection,
        key: CanvasShortcutKey
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "moveNode\(nodeDirectionIDSuffix(direction))"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Node",
                verb: "Move \(nodeDirectionLabel(direction))"
            ),
            gesture: CanvasShortcutGesture(key: key, modifiers: [.command]),
            action: .apply(commands: [.moveNode(direction)]),
            shortcutLabel: shortcutLabel(for: CanvasShortcutGesture(key: key, modifiers: [.command])),
            commandPaletteVisibility: .requiresFocusedNode,
            executionCondition: nodeExecutionCondition(for: .requiresFocusedNode)
        )
    }

    private static func nodeNudgeDefinition(
        direction: CanvasNodeMoveDirection,
        key: CanvasShortcutKey
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "nudgeNode\(nodeDirectionIDSuffix(direction))"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Node",
                verb: "Move \(nodeDirectionLabel(direction)) Slightly"
            ),
            gesture: CanvasShortcutGesture(key: key, modifiers: [.command, .shift]),
            action: .apply(commands: [.nudgeNode(direction)]),
            shortcutLabel: shortcutLabel(
                for: CanvasShortcutGesture(key: key, modifiers: [.command, .shift])
            ),
            searchTokens: ["move", "slightly", "nudge", "grid"],
            commandPaletteVisibility: .requiresFocusedNodeAndMode([.diagram]),
            executionCondition: nodeExecutionCondition(for: .requiresFocusedNodeAndMode([.diagram]))
        )
    }

<<<<<<< HEAD
=======
    private static func historyDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "undo"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "History", verb: "Undo"),
                gesture: CanvasShortcutGesture(key: .character("z"), modifiers: [.command]),
                action: .undo,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("z"), modifiers: [.command])
                )
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "redo.commandShiftZ"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "History", verb: "Redo"),
                gesture: CanvasShortcutGesture(key: .character("z"), modifiers: [.command, .shift]),
                action: .redo,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("z"), modifiers: [.command, .shift])
                )
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "redo.commandY"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "History", verb: "Redo"),
                gesture: CanvasShortcutGesture(key: .character("y"), modifiers: [.command]),
                action: .redo,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("y"), modifiers: [.command])
                )
            ),
        ]
    }

>>>>>>> main
}
