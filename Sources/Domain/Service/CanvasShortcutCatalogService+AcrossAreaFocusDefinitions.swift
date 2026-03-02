// Background: Area-cross focus shortcuts are kept separate to avoid growing the main catalog file.
// Responsibility: Provide command-option-arrow shortcut definitions for across-area root focus.
extension CanvasShortcutCatalogService {
    static func focusMoveAcrossAreasDefinitions() -> [CanvasShortcutDefinition] {
        [
            focusMoveAcrossAreasDefinition(direction: .left, key: .arrowLeft),
            focusMoveAcrossAreasDefinition(direction: .right, key: .arrowRight),
        ]
    }

    private static func focusMoveAcrossAreasDefinition(
        direction: CanvasFocusDirection,
        key: CanvasShortcutKey
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "moveFocusAcrossAreasToRoot\(focusDirectionIDSuffix(direction))"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Focus",
                verb: "Move Across Areas \(focusDirectionLabel(direction))"
            ),
            gesture: CanvasShortcutGesture(key: key, modifiers: [.command, .option]),
            action: .apply(commands: [.moveFocusAcrossAreasToRoot(direction)]),
            shortcutLabel: shortcutLabelForAcrossAreaFocus(key),
            searchTokens: ["focus", "area", "across", "root", "oldest"],
            commandPaletteVisibility: .requiresFocusedNode
        )
    }

    private static func shortcutLabelForAcrossAreaFocus(_ key: CanvasShortcutKey) -> String {
        switch key {
        case .arrowLeft:
            return "⌘⌥←"
        case .arrowRight:
            return "⌘⌥→"
        case .arrowUp:
            return "⌘⌥↑"
        case .arrowDown:
            return "⌘⌥↓"
        case .tab, .enter, .deleteBackward, .deleteForward, .character:
            return "⌘⌥"
        }
    }
}
