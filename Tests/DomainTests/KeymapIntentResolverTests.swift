// Background: Keymap primitive redesign requires stable scope classification before adapter migration.
// Responsibility: Verify route resolution for primitive and global shortcut paths.
import Domain
import Testing

@Test("KeymapIntentResolver: command-enter resolves primitive hierarchical add intent")
func test_resolveRoute_commandEnter_returnsPrimitiveAddHierarchical() {
    let gesture = CanvasShortcutGesture(key: .enter, modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .add(variant: .hierarchical)))
}

@Test("KeymapIntentResolver: shift-enter resolves primitive mode-select add intent")
func test_resolveRoute_shiftEnter_returnsPrimitiveAddModeSelect() {
    let gesture = CanvasShortcutGesture(key: .enter, modifiers: [.shift])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .add(variant: .modeSelect)))
}

@Test("KeymapIntentResolver: command-k resolves global command palette action")
func test_resolveRoute_commandK_returnsGlobalOpenCommandPalette() {
    let gesture = CanvasShortcutGesture(key: .character("k"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .openCommandPalette))
}

@Test("KeymapIntentResolver: command-f resolves global search action")
func test_resolveRoute_commandF_returnsGlobalOpenSearch() {
    let gesture = CanvasShortcutGesture(key: .character("f"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .openSearch))
}

@Test("KeymapIntentResolver: command-z resolves global undo action")
func test_resolveRoute_commandZ_returnsGlobalUndo() {
    let gesture = CanvasShortcutGesture(key: .character("z"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .undo))
}

@Test("KeymapIntentResolver: command-l resolves global begin-connect action")
func test_resolveRoute_commandL_returnsGlobalBeginConnectNodeSelection() {
    let gesture = CanvasShortcutGesture(key: .character("l"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .beginConnectNodeSelection))
}

@Test("KeymapIntentResolver: tab resolves primitive switch-target-kind edge intent")
func test_resolveRoute_tab_returnsPrimitiveSwitchTargetKindEdge() {
    let gesture = CanvasShortcutGesture(key: .tab, modifiers: [])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .switchTargetKind(variant: .edge)))
}

@Test("KeymapIntentResolver: control-l resolves global center-focused-node action")
func test_resolveRoute_controlL_returnsGlobalCenterFocusedNode() {
    let gesture = CanvasShortcutGesture(key: .character("l"), modifiers: [.control])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .global(action: .centerFocusedNode))
}

@Test("KeymapIntentResolver: command-c resolves primitive copy-subtree edit intent")
func test_resolveRoute_commandC_returnsPrimitiveEditCopySubtree() {
    let gesture = CanvasShortcutGesture(key: .character("c"), modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .edit(variant: .copySelectionOrFocusedSubtree)))
}

@Test("KeymapIntentResolver: command-down resolves primitive move-node down intent")
func test_resolveRoute_commandDown_returnsPrimitiveMoveNodeDown() {
    let gesture = CanvasShortcutGesture(key: .arrowDown, modifiers: [.command])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .moveNode(direction: .down)))
}

@Test("KeymapIntentResolver: command-option-minus resolves primitive scale-selection-down transform intent")
func test_resolveRoute_commandOptionMinus_returnsPrimitiveScaleSelectionDown() {
    let gesture = CanvasShortcutGesture(key: .character("-"), modifiers: [.command, .option])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .transform(variant: .scaleSelectionDown)))
}

@Test("KeymapIntentResolver: shift-left resolves primitive extend-selection left intent")
func test_resolveRoute_shiftLeft_returnsPrimitiveMoveFocusExtendSelectionLeft() {
    let gesture = CanvasShortcutGesture(key: .arrowLeft, modifiers: [.shift])

    let route = KeymapIntentResolver.resolveRoute(for: gesture)

    #expect(route == .primitive(intent: .moveFocus(direction: .left, variant: .extendSelection)))
}
