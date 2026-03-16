import AppKit
import Domain
import InterfaceAdapters
import Testing

@Test("Shift+Enter はモード選択の追加インテントを解決する")
func test_resolve_shiftEnter_returnsAddModeSelectIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r", modifiers: [.shift])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .add(variant: .modeSelect)))
}

@Test("「add-sibling node-below」インテントを入力すると解決される")
func test_resolve_enter_returnsAddSiblingBelowIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r")

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .add(variant: .primary)))
}

@Test("Option+Enter は、兄弟ノード上の追加インテントを解決する")
func test_resolve_optionEnter_returnsAddSiblingAboveIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r", modifiers: [.option])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .add(variant: .alternate)))
}

@Test("Command+Enter は子ノードの追加インテントを解決する")
func test_resolve_commandEnter_returnsAddChildIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .add(variant: .hierarchical)))
}

@Test("Fn+Enter は nil を解決する")
func test_resolve_functionEnter_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 36, characters: "\r", charactersIgnoringModifiers: "\r", modifiers: [.function])

    let route = sut.resolve(event)

    #expect(route == nil)
}

@Test("Control+L は、中心にフォーカス中のノードのグローバル アクションを解決する")
func test_resolve_controlL_returnsGlobalCenterFocusedNode() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 37, characters: "l", charactersIgnoringModifiers: "l", modifiers: [.control])

    let route = sut.resolve(event)

    #expect(route == .global(action: .centerFocusedNode))
}

@Test("Command+L は begin-connect グローバル アクションを解決する")
func test_resolve_commandL_returnsBeginConnectGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 37, characters: "l", charactersIgnoringModifiers: "l", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .beginConnectNodeSelection))
}

@Test("タブは switch-target-kind サイクル インテントを解決する")
func test_resolve_tab_returnsSwitchTargetKindCycleIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 48, characters: "\t", charactersIgnoringModifiers: "\t")

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .switchTargetKind(variant: .cycle)))
}

@Test("Command+Semicolon はサイクルエッジ方向性インテントを解決する")
func test_resolve_commandSemicolon_returnsCycleEdgeDirectionalityIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 41, characters: ";", charactersIgnoringModifiers: ";", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .cycleFocusedEdgeDirectionality))
}

@Test("Command+Shift+E はエリアのエッジ形状の切り替えインテントを解決する")
func test_resolve_commandShiftE_returnsToggleAreaEdgeShapeIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 14,
        characters: "E",
        charactersIgnoringModifiers: "e",
        modifiers: [.command, .shift]
    )

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .edit(variant: .toggleFocusedAreaEdgeShapeStyle)))
}

@Test("Option+Period は可視性の切り替えインテントを解決する")
func test_resolve_optionPeriod_returnsToggleVisibilityIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 47, characters: "≥", charactersIgnoringModifiers: ".", modifiers: [.option])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .toggleVisibility))
}

@Test("上矢印は移動フォーカス上インテントを解決する")
func test_resolve_upArrow_returnsMoveFocusUpIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 126, characters: "↑", charactersIgnoringModifiers: "↑")

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .moveFocus(direction: .up, variant: .single)))
}

@Test("Command+Down はノード移動インテントを解決する")
func test_resolve_commandDownArrow_returnsMoveNodeDownIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 125, characters: "↓", charactersIgnoringModifiers: "↓", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .moveNode(direction: .down)))
}

@Test("Command+Shift+Right はナッジノードの正しいインテントを解決する")
func test_resolve_commandShiftRightArrow_returnsNudgeNodeRightIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 124, characters: "→", charactersIgnoringModifiers: "→", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .nudgeNode(direction: .right)))
}

@Test("Shift+Arrow は選択範囲の拡張インテントを解決する")
func test_resolve_shiftArrow_returnsExtendSelectionIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 123, characters: "←", charactersIgnoringModifiers: "←", modifiers: [.shift])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .moveFocus(direction: .left, variant: .extendSelection)))
}

@Test("Command+Option+Right はエリア全体のフォーカスの意図を解決する")
func test_resolve_commandOptionRightArrow_returnsMoveFocusAcrossAreasToRootIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 124, characters: "→", charactersIgnoringModifiers: "→", modifiers: [.command, .option]
    )

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .moveFocus(direction: .right, variant: .acrossAreasToRoot)))
}

@Test("Function フラグ付きの矢印は引き続き move-focus インテントを解決する")
func test_resolve_functionArrow_returnsMoveFocusIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 124, characters: "→", charactersIgnoringModifiers: "→", modifiers: [.function])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .moveFocus(direction: .right, variant: .single)))
}

@Test("削除により削除の意図が解決される")
func test_resolve_delete_returnsDeleteIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 51, characters: "\u{8}", charactersIgnoringModifiers: "\u{8}")

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .delete))
}

@Test("関数を使用した前方削除は削除インテントを解決する")
func test_resolve_forwardDeleteWithFunction_returnsDeleteIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 117, characters: "\u{7F}", charactersIgnoringModifiers: "\u{7F}", modifiers: [.function])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .delete))
}

@Test("Shift キーを押しながら削除すると nil が解決される")
func test_resolve_shiftDelete_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 51, characters: "\u{8}", charactersIgnoringModifiers: "\u{8}", modifiers: [.shift])

    let route = sut.resolve(event)

    #expect(route == nil)
}

@Test("Command+Z は元に戻すグローバル アクションを解決する")
func test_resolve_commandZ_returnsUndoGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 6, characters: "z", charactersIgnoringModifiers: "z", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .undo))
}

@Test("Shift+Command+Z は、REDO グローバル アクションを解決する")
func test_resolve_shiftCommandZ_returnsRedoGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 6, characters: "Z", charactersIgnoringModifiers: "z", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .redo))
}

@Test("Command+Y は、REDO グローバル アクションを解決する")
func test_resolve_commandY_returnsRedoGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 16, characters: "y", charactersIgnoringModifiers: "y", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .redo))
}

@Test("Command+K はコマンドパレットのグローバル アクションを解決する")
func test_resolve_commandK_returnsOpenCommandPaletteGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 40, characters: "k", charactersIgnoringModifiers: "k", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .openCommandPalette))
}

@Test("Command+Shift+P はコマンドパレットのグローバル アクションを解決する")
func test_resolve_commandShiftP_returnsOpenCommandPaletteGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 35, characters: "P", charactersIgnoringModifiers: "p", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .openCommandPalette))
}

@Test("Command+Function+K は nil を解決する")
func test_resolve_commandFunctionK_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 40, characters: "k", charactersIgnoringModifiers: "k", modifiers: [.command, .function])

    let route = sut.resolve(event)

    #expect(route == nil)
}

@Test("Command+F は検索グローバル アクションを解決する")
func test_resolve_commandF_returnsOpenSearchGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 3, characters: "f", charactersIgnoringModifiers: "f", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .openSearch))
}

@Test("Command+Shift+F は nil を解決する")
func test_resolve_commandShiftF_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 3, characters: "F", charactersIgnoringModifiers: "f", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == nil)
}

@Test("Caps Lock を使用した Command+F は検索グローバル アクションを解決する")
func test_resolve_commandFWithCapsLock_returnsOpenSearchGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 3, characters: "f", charactersIgnoringModifiers: "f", modifiers: [.command, .capsLock])

    let route = sut.resolve(event)

    #expect(route == .global(action: .openSearch))
}

@Test("Command+Shift+= ズームイン グローバル アクションを解決する")
func test_resolve_commandShiftEquals_returnsZoomInGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 24, characters: "+", charactersIgnoringModifiers: "=", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .zoomIn))
}

@Test("Command+- ズームアウト グローバル アクションを解決する")
func test_resolve_commandMinus_returnsZoomOutGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 27, characters: "-", charactersIgnoringModifiers: "-", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .global(action: .zoomOut))
}

@Test("Command+Shift+semicolon はズームイン グローバル アクションを解決する")
func test_resolve_commandShiftSemicolon_returnsZoomInGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 41, characters: "+", charactersIgnoringModifiers: ";", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .zoomIn))
}

@Test("Command+Shift+equals キーコードはズームイン グローバル アクションを解決する")
func test_resolve_commandShiftEqualsKeyCode_returnsZoomInGlobalAction() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 24, characters: "=", charactersIgnoringModifiers: "=", modifiers: [.command, .shift])

    let route = sut.resolve(event)

    #expect(route == .global(action: .zoomIn))
}

@Test("Command+Option+- スケール選択ダウンの意図を解決する")
func test_resolve_commandOptionMinus_returnsScaleSelectionDownIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 27, characters: "-", charactersIgnoringModifiers: "-", modifiers: [.command, .option])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .transform(variant: .scaleSelectionDown)))
}

@Test("Command+Option+Shift+= はスケールアップの選択意図を解決する")
func test_resolve_commandOptionShiftEquals_returnsScaleSelectionUpIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(
        keyCode: 24, characters: "+", charactersIgnoringModifiers: "=", modifiers: [.command, .option, .shift])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .transform(variant: .scaleSelectionUp)))
}

@Test("Command+C は edit copy-subtree インテントを解決する")
func test_resolve_commandC_returnsEditCopySubtreeIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 8, characters: "c", charactersIgnoringModifiers: "c", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .edit(variant: .copySelectionOrFocusedSubtree)))
}

@Test("Command+X は編集カットサブツリーインテントを解決する")
func test_resolve_commandX_returnsEditCutSubtreeIntent() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try makeKeyEvent(keyCode: 7, characters: "x", charactersIgnoringModifiers: "x", modifiers: [.command])

    let route = sut.resolve(event)

    #expect(route == .primitive(intent: .edit(variant: .cutSelectionOrFocusedSubtree)))
}

@Test("Command+V は、編集、貼り付け、サブツリーのインテントを解決する")
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
