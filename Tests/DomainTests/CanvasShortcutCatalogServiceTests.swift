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

@Test("Shortcut catalog: command palette definitions exclude open palette trigger")
func test_commandPaletteDefinitions_excludeOpenPaletteAction() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()

    #expect(!definitions.isEmpty)
    #expect(definitions.allSatisfy { $0.isVisibleInCommandPalette })
    #expect(!definitions.contains(where: { $0.action == .openCommandPalette }))
}

@Test("Shortcut catalog: command-plus resolves zoom in")
func test_resolveAction_commandPlus_returnsZoomIn() {
    let gesture = CanvasShortcutGesture(key: .character("+"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomIn)
}

@Test("Shortcut catalog: command-shift-semicolon resolves zoom in")
func test_resolveAction_commandShiftSemicolon_returnsZoomIn() {
    let gesture = CanvasShortcutGesture(key: .character(";"), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomIn)
}

@Test("Shortcut catalog: command+c resolves copyFocusedSubtree")
func test_resolveAction_commandC_returnsCopyFocusedSubtree() {
    let gesture = CanvasShortcutGesture(key: .character("c"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.copyFocusedSubtree]))
}

@Test("Shortcut catalog: command+x resolves cutFocusedSubtree")
func test_resolveAction_commandX_returnsCutFocusedSubtree() {
    let gesture = CanvasShortcutGesture(key: .character("x"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.cutFocusedSubtree]))
}

@Test("Shortcut catalog: command+v resolves pasteSubtreeAsChild")
func test_resolveAction_commandV_returnsPasteSubtreeAsChild() {
    let gesture = CanvasShortcutGesture(key: .character("v"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.pasteSubtreeAsChild]))
}

@Test("Shortcut catalog: shift+left resolves extendSelection")
func test_resolveAction_shiftLeft_returnsExtendSelection() {
    let gesture = CanvasShortcutGesture(key: .arrowLeft, modifiers: [.shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.extendSelection(.left)]))
}
