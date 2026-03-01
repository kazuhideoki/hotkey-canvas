import AppKit
import Domain
import InterfaceAdapters
import Testing

@Test("CanvasHotkeyTranslator: Shift+Enter resolves mode-select add intent")
func test_resolve_shiftEnter_returnsAddModeSelectIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r", modifiers: [.shift])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .add(variant: .modeSelect)))
}

@Test("CanvasHotkeyTranslator: Enter resolves add-sibling-below intent")
func test_resolve_enter_returnsAddSiblingBelowIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r")

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .add(variant: .primary)))
}

@Test("CanvasHotkeyTranslator: Option+Enter resolves add-sibling-above intent")
func test_resolve_optionEnter_returnsAddSiblingAboveIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r", modifiers: [.option])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .add(variant: .alternate)))
}

@Test("CanvasHotkeyTranslator: Command+Enter resolves add-child intent")
func test_resolve_commandEnter_returnsAddChildIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .add(variant: .hierarchical)))
}

@Test("CanvasHotkeyTranslator: Fn+Enter resolves nil")
func test_resolve_functionEnter_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r", modifiers: [.function])

    let route = sut.resolve(event)

    #expect(route == nil)
}

@Test("CanvasHotkeyTranslator: Control+L resolves center-focused-node global action")
func test_resolve_controlL_returnsGlobalCenterFocusedNode() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 37, characters: "l", charactersIgnoringModifiers: "l", modifiers: [.control])

    let route = sut.resolve(event)

    #expect(route == .global(action: .centerFocusedNode))
}

@Test("CanvasHotkeyTranslator: Command+L resolves begin-connect global action")
func test_resolve_commandL_returnsBeginConnectGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 37, characters: "l", charactersIgnoringModifiers: "l", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .beginConnectNodeSelection))
}

@Test("CanvasHotkeyTranslator: Tab resolves switch-target-kind cycle intent")
func test_resolve_tab_returnsSwitchTargetKindCycleIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 48, characters: "\t", charactersIgnoringModifiers: "\t")

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .switchTargetKind(variant: .cycle)))
}

@Test("CanvasHotkeyTranslator: Command+Semicolon resolves cycle-edge-directionality intent")
func test_resolve_commandSemicolon_returnsCycleEdgeDirectionalityIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 41, characters: ";", charactersIgnoringModifiers: ";", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .cycleFocusedEdgeDirectionality))
}

@Test("CanvasHotkeyTranslator: Option+Period resolves toggle-visibility intent")
func test_resolve_optionPeriod_returnsToggleVisibilityIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 47, characters: "≥", charactersIgnoringModifiers: ".", modifiers: [.option])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .toggleVisibility))
}

@Test("CanvasHotkeyTranslator: Up arrow resolves move-focus up intent")
func test_resolve_upArrow_returnsMoveFocusUpIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 126, characters: "↑", charactersIgnoringModifiers: "↑")

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .moveFocus(direction: .up, variant: .single)))
}

@Test("CanvasHotkeyTranslator: Command+Down resolves move-node down intent")
func test_resolve_commandDownArrow_returnsMoveNodeDownIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 125, characters: "↓", charactersIgnoringModifiers: "↓", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .moveNode(direction: .down)))
}

@Test("CanvasHotkeyTranslator: Command+Shift+Right resolves nudge-node right intent")
func test_resolve_commandShiftRightArrow_returnsNudgeNodeRightIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 124, characters: "→", charactersIgnoringModifiers: "→", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .nudgeNode(direction: .right)))
}

@Test("CanvasHotkeyTranslator: Shift+Arrow resolves extend-selection intent")
func test_resolve_shiftArrow_returnsExtendSelectionIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 123, characters: "←", charactersIgnoringModifiers: "←", modifiers: [.shift])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .moveFocus(direction: .left, variant: .extendSelection)))
}

@Test("CanvasHotkeyTranslator: Arrow with Function flag still resolves move-focus intent")
func test_resolve_functionArrow_returnsMoveFocusIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 124, characters: "→", charactersIgnoringModifiers: "→", modifiers: [.function])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .moveFocus(direction: .right, variant: .single)))
}

@Test("CanvasHotkeyTranslator: Delete resolves delete intent")
func test_resolve_delete_returnsDeleteIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 51, characters: "\u{8}", charactersIgnoringModifiers: "\u{8}")

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .delete))
}

@Test("CanvasHotkeyTranslator: Forward delete with Function resolves delete intent")
func test_resolve_forwardDeleteWithFunction_returnsDeleteIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 117, characters: "\u{7F}", charactersIgnoringModifiers: "\u{7F}", modifiers: [.function])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .delete))
}

@Test("CanvasHotkeyTranslator: Delete with Shift resolves nil")
func test_resolve_shiftDelete_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 51, characters: "\u{8}", charactersIgnoringModifiers: "\u{8}", modifiers: [.shift])

    let route = sut.resolve(event)

    #expect(route == nil)
}

@Test("CanvasHotkeyTranslator: Command+Z resolves undo global action")
func test_resolve_commandZ_returnsUndoGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 6, characters: "z", charactersIgnoringModifiers: "z", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .undo))
}

@Test("CanvasHotkeyTranslator: Shift+Command+Z resolves redo global action")
func test_resolve_shiftCommandZ_returnsRedoGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 6, characters: "Z", charactersIgnoringModifiers: "z", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .redo))
}

@Test("CanvasHotkeyTranslator: Command+Y resolves redo global action")
func test_resolve_commandY_returnsRedoGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 16, characters: "y", charactersIgnoringModifiers: "y", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .redo))
}

@Test("CanvasHotkeyTranslator: Command+K resolves command-palette global action")
func test_resolve_commandK_returnsOpenCommandPaletteGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 40, characters: "k", charactersIgnoringModifiers: "k", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .openCommandPalette))
}

@Test("CanvasHotkeyTranslator: Command+Shift+P resolves command-palette global action")
func test_resolve_commandShiftP_returnsOpenCommandPaletteGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 35, characters: "P", charactersIgnoringModifiers: "p", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .openCommandPalette))
}

@Test("CanvasHotkeyTranslator: Command+Function+K resolves nil")
func test_resolve_commandFunctionK_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 40, characters: "k", charactersIgnoringModifiers: "k", modifiers: [.command, .function])

    let route = sut.resolve(event)

    #expect(route == nil)
}

@Test("CanvasHotkeyTranslator: Command+F resolves search global action")
func test_resolve_commandF_returnsOpenSearchGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 3, characters: "f", charactersIgnoringModifiers: "f", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .openSearch))
}

@Test("CanvasHotkeyTranslator: Command+Shift+F resolves nil")
func test_resolve_commandShiftF_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 3, characters: "F", charactersIgnoringModifiers: "f", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == nil)
}

@Test("CanvasHotkeyTranslator: Command+F with Caps Lock resolves search global action")
func test_resolve_commandFWithCapsLock_returnsOpenSearchGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 3, characters: "f", charactersIgnoringModifiers: "f", modifiers: [.command, .capsLock])

    let route = sut.resolve(event)

    #expect(route == .global(action: .openSearch))
}

@Test("CanvasHotkeyTranslator: Command+Shift+= resolves zoom-in global action")
func test_resolve_commandShiftEquals_returnsZoomInGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 24, characters: "+", charactersIgnoringModifiers: "=", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .zoomIn))
}

@Test("CanvasHotkeyTranslator: Command+- resolves zoom-out global action")
func test_resolve_commandMinus_returnsZoomOutGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 27, characters: "-", charactersIgnoringModifiers: "-", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .zoomOut))
}

@Test("CanvasHotkeyTranslator: Command+Shift+semicolon resolves zoom-in global action")
func test_resolve_commandShiftSemicolon_returnsZoomInGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 41, characters: "+", charactersIgnoringModifiers: ";", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .zoomIn))
}

@Test("CanvasHotkeyTranslator: Command+Shift+equals keycode resolves zoom-in global action")
func test_resolve_commandShiftEqualsKeyCode_returnsZoomInGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 24, characters: "=", charactersIgnoringModifiers: "=", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .zoomIn))
}

@Test("CanvasHotkeyTranslator: Command+Option+- resolves scale-selection-down intent")
func test_resolve_commandOptionMinus_returnsScaleSelectionDownIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 27, characters: "-", charactersIgnoringModifiers: "-", modifiers: [.command, .option])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .transform(variant: .scaleSelectionDown)))
}

@Test("CanvasHotkeyTranslator: Command+Option+Shift+= resolves scale-selection-up intent")
func test_resolve_commandOptionShiftEquals_returnsScaleSelectionUpIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 24, characters: "+", charactersIgnoringModifiers: "=", modifiers: [.command, .option, .shift])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .transform(variant: .scaleSelectionUp)))
}

@Test("CanvasHotkeyTranslator: Command+C resolves edit copy-subtree intent")
func test_resolve_commandC_returnsEditCopySubtreeIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 8, characters: "c", charactersIgnoringModifiers: "c", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .edit(variant: .copySelectionOrFocusedSubtree)))
}

@Test("CanvasHotkeyTranslator: Command+X resolves edit cut-subtree intent")
func test_resolve_commandX_returnsEditCutSubtreeIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 7, characters: "x", charactersIgnoringModifiers: "x", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .edit(variant: .cutSelectionOrFocusedSubtree)))
}

@Test("CanvasHotkeyTranslator: Command+V resolves edit paste-subtree intent")
func test_resolve_commandV_returnsEditPasteSubtreeIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 9, characters: "v", charactersIgnoringModifiers: "v", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .edit(variant: .pasteClipboardAtFocusedNode)))
}

private func makeKeyEvent(
    keyCode: UInt16,
    characters: String,
    charactersIgnoringModifiers: String,
    modifiers: NSEvent.ModifierFlags = []
) throws -> NSEvent {
    try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: keyCode
        )
    )
}
