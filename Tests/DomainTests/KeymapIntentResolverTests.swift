// Background: Keymap primitive redesign requires stable scope classification before adapter migration.
// Responsibility: Verify route resolution for primitive and global shortcut paths.
import Domain
import Testing

@Test("command-enter はプリミティブな階層追加インテントを解決する")
func test_resolveRoute_commandEnter_returnsPrimitiveAddHierarchical() {
    let gesture = CanvasShortcutGesture(key: .enter, modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .add(variant: .hierarchical)))
}

@Test("shift-enter はプリミティブ モードを解決する - 追加インテントを選択する")
func test_resolveRoute_shiftEnter_returnsPrimitiveAddModeSelect() {
    let gesture = CanvasShortcutGesture(key: .enter, modifiers: [.shift])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .add(variant: .modeSelect)))
}

@Test("command-k はグローバル コマンドパレット アクションを解決する")
func test_resolveRoute_commandK_returnsGlobalOpenCommandPalette() {
    let gesture = CanvasShortcutGesture(key: .character("k"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .openCommandPalette))
}

@Test("command-f はグローバル検索アクションを解決する")
func test_resolveRoute_commandF_returnsGlobalOpenSearch() {
    let gesture = CanvasShortcutGesture(key: .character("f"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .openSearch))
}

@Test("command-z はグローバルな元に戻すアクションを解決する")
func test_resolveRoute_commandZ_returnsGlobalUndo() {
    let gesture = CanvasShortcutGesture(key: .character("z"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .undo))
}

@Test("command-l はグローバル接続開始アクションを解決する")
func test_resolveRoute_commandL_returnsGlobalBeginConnectNodeSelection() {
    let gesture = CanvasShortcutGesture(key: .character("l"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .beginConnectNodeSelection))
}

@Test("タブはプリミティブな switch-target-kind サイクル インテントを解決する")
func test_resolveRoute_tab_returnsPrimitiveSwitchTargetKindCycle() {
    let gesture = CanvasShortcutGesture(key: .tab, modifiers: [])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .switchTargetKind(variant: .cycle)))
}

@Test("control-l は、グローバルなセンター中心ノードのアクションを解決する")
func test_resolveRoute_controlL_returnsGlobalCenterFocusedNode() {
    let gesture = CanvasShortcutGesture(key: .character("l"), modifiers: [.control])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .centerFocusedNode))
}

@Test("command-c はプリミティブなコピーサブツリー編集意図を解決する")
func test_resolveRoute_commandC_returnsPrimitiveEditCopySubtree() {
    let gesture = CanvasShortcutGesture(key: .character("c"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .edit(variant: .copySelectionOrFocusedSubtree)))
}

@Test("command-down はプリミティブなノードダウン移動インテントを解決する")
func test_resolveRoute_commandDown_returnsPrimitiveMoveNodeDown() {
    let gesture = CanvasShortcutGesture(key: .arrowDown, modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .moveNode(direction: .down)))
}

@Test("command-option-minus は、プリミティブなスケール選択ダウン変換の意図を解決する")
func test_resolveRoute_commandOptionMinus_returnsPrimitiveScaleSelectionDown() {
    let gesture = CanvasShortcutGesture(key: .character("-"), modifiers: [.command, .option])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .transform(variant: .scaleSelectionDown)))
}

@Test("shift-left はプリミティブ拡張選択左インテントを解決する")
func test_resolveRoute_shiftLeft_returnsPrimitiveMoveFocusExtendSelectionLeft() {
    let gesture = CanvasShortcutGesture(key: .arrowLeft, modifiers: [.shift])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .moveFocus(direction: .left, variant: .extendSelection)))
}

@Test("command-option-right は、原始的なエリア間フォーカスの意図を解決する")
func test_resolveRoute_commandOptionRight_returnsPrimitiveMoveFocusAcrossAreasToRoot() {
    let gesture = CanvasShortcutGesture(key: .arrowRight, modifiers: [.command, .option])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .moveFocus(direction: .right, variant: .acrossAreasToRoot)))
}

@Test("command-shift-e はエリアのエッジ形状の切り替え編集インテントを解決する")
func test_resolveRoute_commandShiftE_returnsPrimitiveEditToggleAreaEdgeShape() {
    let gesture = CanvasShortcutGesture(key: .character("e"), modifiers: [.command, .shift])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .edit(variant: .toggleFocusedAreaEdgeShapeStyle)))
}
