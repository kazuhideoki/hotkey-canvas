// Background: Shortcut catalog is now a core domain source for both event resolution and command palette listing.
// Responsibility: Verify catalog invariants and default shortcut resolution behavior.
import Domain
import Testing

@Test("Shortcut catalog: default definitions are valid")
func test_defaultDefinitions_areValid() throws {
    let definitions = CanvasShortcutCatalogService.defaultDefinitions()

    #expect(!definitions.isEmpty)
    try CanvasShortcutCatalogService.validate(definitions: definitions)
}

@Test("Shortcut catalog: command-enter resolves addChildNode")
func test_resolveAction_commandEnter_returnsAddChildNode() {
    let gesture = CanvasShortcutGesture(key: .enter, modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.addChildNode]))
}

@Test("Shortcut catalog: command-shift-p resolves open command palette")
func test_resolveAction_commandShiftP_returnsOpenCommandPalette() {
    let gesture = CanvasShortcutGesture(key: .character("p"), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .openCommandPalette)
}

@Test("Shortcut catalog: command palette definitions exclude open palette trigger")
func test_commandPaletteDefinitions_excludeOpenPaletteAction() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()

    #expect(!definitions.isEmpty)
    #expect(definitions.allSatisfy { $0.isVisibleInCommandPalette })
    #expect(!definitions.contains(where: { $0.action == .openCommandPalette }))
}

@Test("Shortcut catalog validation: duplicate identifier throws")
func test_validate_duplicateID_throwsError() {
    let definition = CanvasShortcutDefinition(
        id: CanvasShortcutID(rawValue: "duplicate"),
        name: "Add Node",
        gesture: CanvasShortcutGesture(key: .enter, modifiers: [.shift]),
        action: .apply(commands: [.addNode]),
        shortcutLabel: "Shift + Enter"
    )

    #expect(throws: CanvasShortcutCatalogError.duplicateID(definition.id)) {
        try CanvasShortcutCatalogService.validate(definitions: [definition, definition])
    }
}

@Test("Shortcut catalog validation: duplicate gesture throws")
func test_validate_duplicateGesture_throwsError() {
    let first = CanvasShortcutDefinition(
        id: CanvasShortcutID(rawValue: "undo"),
        name: "Undo",
        gesture: CanvasShortcutGesture(key: .character("z"), modifiers: [.command]),
        action: .undo,
        shortcutLabel: "Command + Z"
    )
    let second = CanvasShortcutDefinition(
        id: CanvasShortcutID(rawValue: "duplicateUndo"),
        name: "Undo Duplicate",
        gesture: CanvasShortcutGesture(key: .character("z"), modifiers: [.command]),
        action: .undo,
        shortcutLabel: "Command + Z"
    )

    #expect(throws: CanvasShortcutCatalogError.duplicateGesture(first.gesture)) {
        try CanvasShortcutCatalogService.validate(definitions: [first, second])
    }
}
