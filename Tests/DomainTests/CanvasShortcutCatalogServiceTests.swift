// Background: Shortcut catalog is now a core domain source for both event resolution and command palette listing.
// Responsibility: Verify catalog invariants and default shortcut resolution behavior.
import Domain
import Testing

@Test("Shortcut catalog: command-enter resolves addChildNode")
func test_resolveAction_commandEnter_returnsAddChildNode() {
    let gesture = CanvasShortcutGesture(key: .enter, modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.addChildNode]))
}

@Test("Shortcut catalog: control+l resolves centerFocusedNode")
func test_resolveAction_controlL_returnsCenterFocusedNode() {
    let gesture = CanvasShortcutGesture(key: .character("l"), modifiers: [.control])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.centerFocusedNode]))
}

@Test("Shortcut catalog: command+l resolves beginConnectNodeSelection")
func test_resolveAction_commandL_returnsBeginConnectNodeSelection() {
    let gesture = CanvasShortcutGesture(key: .character("l"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .beginConnectNodeSelection)
}

@Test("Shortcut catalog: option+period resolves toggleFoldFocusedSubtree")
func test_resolveAction_optionPeriod_returnsToggleFoldFocusedSubtree() {
    let gesture = CanvasShortcutGesture(key: .character("."), modifiers: [.option])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.toggleFoldFocusedSubtree]))
}

@Test("Shortcut catalog: command-shift-p resolves open command palette")
func test_resolveAction_commandShiftP_returnsOpenCommandPalette() {
    let gesture = CanvasShortcutGesture(key: .character("p"), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .openCommandPalette)
}

@Test("Shortcut catalog: command-shift-equals resolves zoom in")
func test_resolveAction_commandShiftEquals_returnsZoomIn() {
    let gesture = CanvasShortcutGesture(key: .character("="), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomIn)
}

@Test("Shortcut catalog: command-minus resolves zoom out")
func test_resolveAction_commandMinus_returnsZoomOut() {
    let gesture = CanvasShortcutGesture(key: .character("-"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomOut)
}

@Test("Shortcut catalog: command-option-minus resolves scale selected nodes down")
func test_resolveAction_commandOptionMinus_returnsScaleSelectedNodesDown() {
    let gesture = CanvasShortcutGesture(key: .character("-"), modifiers: [.command, .option])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.scaleSelectedNodes(.down)]))
}

@Test("Shortcut catalog: command palette definitions exclude open palette trigger")
func test_commandPaletteDefinitions_excludeOpenPaletteAction() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()

    #expect(!definitions.isEmpty)
    #expect(definitions.allSatisfy { $0.isVisibleInCommandPalette })
    #expect(!definitions.contains(where: { $0.action == .openCommandPalette }))
}

@Test("Shortcut catalog: command palette labels use symbol notation")
func test_commandPaletteDefinitions_useSymbolShortcutLabels() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()
    let labelsByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id.rawValue, $0.shortcutLabel) })

    #expect(labelsByID["addChildNode"] == "⌘↩")
    #expect(labelsByID["extendSelectionUp"] == "⇧↑")
    #expect(labelsByID["centerFocusedNode"] == "⌃L")
    #expect(labelsByID["toggleFoldFocusedSubtree"] == "⌥.")
    #expect(labelsByID["zoomIn.commandShiftEquals"] == "⌘+")
}

@Test("Shortcut catalog: command palette titles use noun-colon-verb format")
func test_commandPaletteDefinitions_useNounColonVerbTitles() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()

    #expect(!definitions.isEmpty)
    #expect(
        definitions.allSatisfy { definition in
            let parts = definition.title.split(separator: ":")
            guard parts.count == 2 else {
                return false
            }
            return !parts[0].trimmingCharacters(in: .whitespaces).isEmpty
                && !parts[1].trimmingCharacters(in: .whitespaces).isEmpty
        }
    )
}

@Test("Shortcut catalog: fold command uses toggle wording")
func test_commandPaletteDefinitions_toggleCommand_usesToggleVerb() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()
    let definitionByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id.rawValue, $0) })

    #expect(definitionByID["toggleFoldFocusedSubtree"]?.title == "Subtree: Toggle Fold")
    #expect(definitionByID["toggleFoldFocusedSubtree"]?.searchTokens.contains("focused") == true)
}

@Test("Shortcut catalog: command-plus resolves zoom in")
func test_resolveAction_commandPlus_returnsZoomIn() {
    let gesture = CanvasShortcutGesture(key: .character("+"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomIn)
}

@Test("Shortcut catalog: command-option-plus resolves scale selected nodes up")
func test_resolveAction_commandOptionPlus_returnsScaleSelectedNodesUp() {
    let gesture = CanvasShortcutGesture(key: .character("+"), modifiers: [.command, .option])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.scaleSelectedNodes(.up)]))
}

@Test("Shortcut catalog: command-shift-semicolon resolves zoom in")
func test_resolveAction_commandShiftSemicolon_returnsZoomIn() {
    let gesture = CanvasShortcutGesture(key: .character(";"), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomIn)
}

@Test("Shortcut catalog: command+c resolves copySelectionOrFocusedSubtree")
func test_resolveAction_commandC_returnsCopyFocusedSubtree() {
    let gesture = CanvasShortcutGesture(key: .character("c"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.copySelectionOrFocusedSubtree]))
}

@Test("Shortcut catalog: command+x resolves cutSelectionOrFocusedSubtree")
func test_resolveAction_commandX_returnsCutFocusedSubtree() {
    let gesture = CanvasShortcutGesture(key: .character("x"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.cutSelectionOrFocusedSubtree]))
}

@Test("Shortcut catalog: command+v resolves pasteClipboardAtFocusedNode")
func test_resolveAction_commandV_returnsPasteSubtreeAsChild() {
    let gesture = CanvasShortcutGesture(key: .character("v"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.pasteClipboardAtFocusedNode]))
}

@Test("Shortcut catalog: command+d resolves duplicateSelectionAsSibling")
func test_resolveAction_commandD_returnsDuplicateSelectionAsSibling() {
    let gesture = CanvasShortcutGesture(key: .character("d"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.duplicateSelectionAsSibling]))
}

@Test("Shortcut catalog: shift+left resolves extendSelection")
func test_resolveAction_shiftLeft_returnsExtendSelection() {
    let gesture = CanvasShortcutGesture(key: .arrowLeft, modifiers: [.shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.extendSelection(.left)]))
}

@Test("Shortcut catalog: diagram context hides tree-only command palette definitions")
func test_commandPaletteDefinitions_diagramContext_hidesTreeOnlyDefinitions() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: true)
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(!ids.contains("addChildNode"))
    #expect(!ids.contains("addSiblingNodeAbove"))
    #expect(!ids.contains("addSiblingNodeBelow"))
    #expect(!ids.contains("duplicateSelectionAsSibling"))
    #expect(!ids.contains("toggleFoldFocusedSubtree"))
    #expect(ids.contains("beginConnectNodeSelection"))
}

@Test("Shortcut catalog: tree context hides diagram-only command palette definitions")
func test_commandPaletteDefinitions_treeContext_hidesDiagramOnlyDefinitions() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: true)
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(ids.contains("addChildNode"))
    #expect(ids.contains("addSiblingNodeAbove"))
    #expect(ids.contains("addSiblingNodeBelow"))
    #expect(!ids.contains("beginConnectNodeSelection"))
    #expect(!ids.contains("nudgeNodeUp"))
    #expect(!ids.contains("nudgeNodeDown"))
    #expect(!ids.contains("nudgeNodeLeft"))
    #expect(!ids.contains("nudgeNodeRight"))
}

@Test("Shortcut catalog: no-focus context hides focus-required command palette definitions")
func test_commandPaletteDefinitions_withoutFocus_hidesFocusRequiredDefinitions() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: false)
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(ids.contains("addNode"))
    #expect(ids.contains("undo"))
    #expect(!ids.contains("addChildNode"))
    #expect(!ids.contains("deleteSelectedOrFocusedNodes"))
    #expect(!ids.contains("centerFocusedNode"))
}

@Test("Shortcut catalog: tree context rewrites copy cut paste labels")
func test_commandPaletteDefinitions_treeContext_rewritesClipboardLabels() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: true)
    )
    let titleByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id.rawValue, $0.title) })

    #expect(titleByID["deleteSelectedOrFocusedNodes"] == "Node: Delete Selected")
    #expect(titleByID["copySelectionOrFocusedSubtree"] == "Node: Copy Selected & Subtree")
    #expect(titleByID["cutSelectionOrFocusedSubtree"] == "Node: Cut Selected & Subtree")
    #expect(titleByID["pasteClipboardAtFocusedNode"] == "Node: Paste As Child")
}

@Test("Shortcut catalog: diagram context rewrites copy cut paste and nudge labels")
func test_commandPaletteDefinitions_diagramContext_rewritesClipboardAndNudgeLabels() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: true)
    )
    let titleByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id.rawValue, $0.title) })

    #expect(titleByID["deleteSelectedOrFocusedNodes"] == "Node: Delete Selected")
    #expect(titleByID["copySelectionOrFocusedSubtree"] == "Node: Copy Selected")
    #expect(titleByID["cutSelectionOrFocusedSubtree"] == "Node: Cut Selected")
    #expect(titleByID["pasteClipboardAtFocusedNode"] == "Node: Paste")
    #expect(titleByID["nudgeNodeUp"] == "Node: Move Up Slightly")
}
