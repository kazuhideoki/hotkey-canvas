// Background: Shortcut catalog is now a core domain source for both event resolution and command palette listing.
// Responsibility: Verify catalog invariants and default shortcut resolution behavior.
import Domain
import Testing

@Test("command-enter は addChildNode を解決する")
func test_resolveAction_commandEnter_returnsAddChildNode() {
    let gesture = CanvasShortcutGesture(key: .enter, modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.addChildNode]))
}

@Test("control+l は centerFocusedNode を解決する")
func test_resolveAction_controlL_returnsCenterFocusedNode() {
    let gesture = CanvasShortcutGesture(key: .character("l"), modifiers: [.control])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.centerFocusedNode]))
}

@Test("command+l は beginConnectNodeSelection を解決する")
func test_resolveAction_commandL_returnsBeginConnectNodeSelection() {
    let gesture = CanvasShortcutGesture(key: .character("l"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .beginConnectNodeSelection)
}

@Test("option+period は toggleFoldFocusedSubtree を解決する")
func test_resolveAction_optionPeriod_returnsToggleFoldFocusedSubtree() {
    let gesture = CanvasShortcutGesture(key: .character("."), modifiers: [.option])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.toggleFoldFocusedSubtree]))
}

@Test("command-shift-p は開いているコマンドパレットを解決する")
func test_resolveAction_commandShiftP_returnsOpenCommandPalette() {
    let gesture = CanvasShortcutGesture(key: .character("p"), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .openCommandPalette)
}

@Test("command-shift-equals はズームインを解決する")
func test_resolveAction_commandShiftEquals_returnsZoomIn() {
    let gesture = CanvasShortcutGesture(key: .character("="), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomIn)
}

@Test("command-minus はズームアウトを解決する")
func test_resolveAction_commandMinus_returnsZoomOut() {
    let gesture = CanvasShortcutGesture(key: .character("-"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomOut)
}

@Test("command-option-minus は選択したノードのスケールダウンを解決する")
func test_resolveAction_commandOptionMinus_returnsScaleSelectedNodesDown() {
    let gesture = CanvasShortcutGesture(key: .character("-"), modifiers: [.command, .option])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.scaleSelectedNodes(.down)]))
}

@Test("コマンドパレット定義ではオープン パレット トリガーを除外する")
func test_commandPaletteDefinitions_excludeOpenPaletteAction() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()

    #expect(!definitions.isEmpty)
    #expect(definitions.allSatisfy { $0.isVisibleInCommandPalette })
    #expect(!definitions.contains(where: { $0.action == .openCommandPalette }))
}

@Test("コマンドパレットのラベルは記号表記を使う")
func test_commandPaletteDefinitions_useSymbolShortcutLabels() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()
    let labelsByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id.rawValue, $0.shortcutLabel) })

    #expect(labelsByID["addChildNode"] == "⌘↩")
    #expect(labelsByID["extendSelectionUp"] == "⇧↑")
    #expect(labelsByID["centerFocusedNode"] == "⌃L")
    #expect(labelsByID["toggleFoldFocusedSubtree"] == "⌥.")
    #expect(labelsByID["zoomIn.commandShiftEquals"] == "⌘⇧+")
}

@Test("コマンドパレットのタイトルは名詞-コロン-動詞の形式を使う")
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

@Test("フォールドコマンドはトグル文言を使う")
func test_commandPaletteDefinitions_toggleCommand_usesToggleVerb() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()
    let definitionByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id.rawValue, $0) })

    #expect(definitionByID["toggleFoldFocusedSubtree"]?.title == "Subtree: Toggle Fold")
    #expect(definitionByID["toggleFoldFocusedSubtree"]?.searchTokens.contains("focused") == true)
}

@Test("command-plus はズームインを解決する")
func test_resolveAction_commandPlus_returnsZoomIn() {
    let gesture = CanvasShortcutGesture(key: .character("+"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomIn)
}

@Test("command-option-plus は選択したノードのスケールアップを解決する")
func test_resolveAction_commandOptionPlus_returnsScaleSelectedNodesUp() {
    let gesture = CanvasShortcutGesture(key: .character("+"), modifiers: [.command, .option])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.scaleSelectedNodes(.up)]))
}

@Test("command-shift-semicolon はズームインを解決する")
func test_resolveAction_commandShiftSemicolon_returnsZoomIn() {
    let gesture = CanvasShortcutGesture(key: .character(";"), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .zoomIn)
}

@Test("command+c は copySelectionOrFocusedSubtree を解決する")
func test_resolveAction_commandC_returnsCopyFocusedSubtree() {
    let gesture = CanvasShortcutGesture(key: .character("c"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.copySelectionOrFocusedSubtree]))
}

@Test("command+x は cutSelectionOrFocusedSubtree を解決する")
func test_resolveAction_commandX_returnsCutFocusedSubtree() {
    let gesture = CanvasShortcutGesture(key: .character("x"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.cutSelectionOrFocusedSubtree]))
}

@Test("command+v は pasteClipboardAtFocusedNode を解決する")
func test_resolveAction_commandV_returnsPasteSubtreeAsChild() {
    let gesture = CanvasShortcutGesture(key: .character("v"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.pasteClipboardAtFocusedNode]))
}

@Test("command+d は duplicateSelectionAsSibling を解決する")
func test_resolveAction_commandD_returnsDuplicateSelectionAsSibling() {
    let gesture = CanvasShortcutGesture(key: .character("d"), modifiers: [.command])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.duplicateSelectionAsSibling]))
}

@Test("shift+left は extendSelection を解決する")
func test_resolveAction_shiftLeft_returnsExtendSelection() {
    let gesture = CanvasShortcutGesture(key: .arrowLeft, modifiers: [.shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.extendSelection(.left)]))
}

@Test("command-option-right は moveFocusAcrossAreasToRoot を解決する")
func test_resolveAction_commandOptionRight_returnsMoveFocusAcrossAreasToRoot() {
    let gesture = CanvasShortcutGesture(key: .arrowRight, modifiers: [.command, .option])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.moveFocusAcrossAreasToRoot(.right)]))
}

@Test("moveFocusAcrossAreasToRoot はエッジ ターゲットで無効になっています")
func test_moveFocusAcrossAreasToRoot_isDisabledInEdgeTarget() {
    let definition = CanvasShortcutCatalogService.definition(for: .moveFocusAcrossAreasToRoot(.right))

    #expect(definition != nil)
    #expect(
        definition.map {
            !KeymapExecutionPolicyResolver.isEnabled(
                definition: $0,
                context: KeymapExecutionContext(
                    editingMode: .diagram,
                    operationTargetKind: .edge,
                    hasFocusedNode: true
                )
            )
        } == true
    )
}

@Test("addNode および addChildNode はエッジ ターゲットで無効になっています")
func test_addNodeCommands_areDisabledInEdgeTarget() {
    let addNodeDefinition = CanvasShortcutCatalogService.definition(for: .addNode)
    let addChildDefinition = CanvasShortcutCatalogService.definition(for: .addChildNode)
    let edgeContext = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true
    )

    #expect(addNodeDefinition != nil)
    #expect(addChildDefinition != nil)
    #expect(
        addNodeDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeContext)
        } == true
    )
    #expect(
        addChildDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeContext)
        } == true
    )
}

@Test("ツリーのノード追加コマンドはエッジターゲットで無効になる")
func test_treeAddCommands_areDisabledInEdgeTarget() {
    let addSiblingAboveDefinition = CanvasShortcutCatalogService.definition(for: .addSiblingNode(position: .above))
    let addSiblingBelowDefinition = CanvasShortcutCatalogService.definition(for: .addSiblingNode(position: .below))
    let duplicateDefinition = CanvasShortcutCatalogService.definition(for: .duplicateSelectionAsSibling)
    let edgeTreeContext = KeymapExecutionContext(
        editingMode: .tree,
        operationTargetKind: .edge,
        hasFocusedNode: true
    )

    #expect(addSiblingAboveDefinition != nil)
    #expect(addSiblingBelowDefinition != nil)
    #expect(duplicateDefinition != nil)
    #expect(
        addSiblingAboveDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeTreeContext)
        } == true
    )
    #expect(
        addSiblingBelowDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeTreeContext)
        } == true
    )
    #expect(
        duplicateDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeTreeContext)
        } == true
    )
}

@Test("エッジ ターゲットではノード変換コマンドが無効になっています")
func test_nodeTransformCommands_areDisabledInEdgeTarget() {
    let moveNodeDefinition = CanvasShortcutCatalogService.definition(for: .moveNode(.right))
    let nudgeNodeDefinition = CanvasShortcutCatalogService.definition(for: .nudgeNode(.right))
    let scaleNodeDefinition = CanvasShortcutCatalogService.definition(for: .scaleSelectedNodes(.up))
    let edgeContext = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true
    )

    #expect(moveNodeDefinition != nil)
    #expect(nudgeNodeDefinition != nil)
    #expect(scaleNodeDefinition != nil)
    #expect(
        moveNodeDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeContext)
        } == true
    )
    #expect(
        nudgeNodeDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeContext)
        } == true
    )
    #expect(
        scaleNodeDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeContext)
        } == true
    )
}

@Test("エッジターゲットではクリップボードコマンドが無効になっています")
func test_clipboardCommands_areDisabledInEdgeTarget() {
    let copyDefinition = CanvasShortcutCatalogService.definition(for: .copySelectionOrFocusedSubtree)
    let cutDefinition = CanvasShortcutCatalogService.definition(for: .cutSelectionOrFocusedSubtree)
    let pasteDefinition = CanvasShortcutCatalogService.definition(for: .pasteClipboardAtFocusedNode)
    let edgeContext = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true
    )

    #expect(copyDefinition != nil)
    #expect(cutDefinition != nil)
    #expect(pasteDefinition != nil)
    #expect(
        copyDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeContext)
        } == true
    )
    #expect(
        cutDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeContext)
        } == true
    )
    #expect(
        pasteDefinition.map {
            !KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: edgeContext)
        } == true
    )
}

@Test("エッジ ターゲットはコマンドパレットで moveFocusAcrossAreasToRoot を非表示にする")
func test_commandPaletteDefinitions_edgeTarget_hidesMoveFocusAcrossAreasToRoot() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: true),
        executionContext: KeymapExecutionContext(
            editingMode: .diagram,
            operationTargetKind: .edge,
            hasFocusedNode: true
        )
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(!ids.contains("moveFocusAcrossAreasToRootLeft"))
    #expect(!ids.contains("moveFocusAcrossAreasToRootRight"))
}

@Test("エッジターゲットはコマンドパレットのノード追加コマンドを非表示にする")
func test_commandPaletteDefinitions_edgeTarget_hidesNodeAddCommands() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: true),
        executionContext: KeymapExecutionContext(
            editingMode: .diagram,
            operationTargetKind: .edge,
            hasFocusedNode: true
        )
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(!ids.contains("addNode"))
    #expect(!ids.contains("addChildNode"))
    #expect(!ids.contains("addSiblingNodeAbove"))
    #expect(!ids.contains("addSiblingNodeBelow"))
}

@Test("エッジ ターゲットはコマンドパレットでノード変換コマンドを非表示にする")
func test_commandPaletteDefinitions_edgeTarget_hidesNodeTransformCommands() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: true),
        executionContext: KeymapExecutionContext(
            editingMode: .diagram,
            operationTargetKind: .edge,
            hasFocusedNode: true
        )
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(!ids.contains("moveNodeUp"))
    #expect(!ids.contains("nudgeNodeUp"))
    #expect(!ids.contains("scaleSelectedNodesUp.commandOptionPlus"))
}

@Test("エッジ ターゲットはコマンドパレットでノードのクリップボード コマンドを非表示にする")
func test_commandPaletteDefinitions_edgeTarget_hidesNodeClipboardCommands() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: true),
        executionContext: KeymapExecutionContext(
            editingMode: .diagram,
            operationTargetKind: .edge,
            hasFocusedNode: true
        )
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(!ids.contains("copySelectionOrFocusedSubtree"))
    #expect(!ids.contains("cutSelectionOrFocusedSubtree"))
    #expect(!ids.contains("pasteClipboardAtFocusedNode"))
}

@Test("ダイアグラム コンテキストは addChild を保持し、ツリーのみのコマンドパレット定義を非表示にする")
func test_commandPaletteDefinitions_diagramContext_hidesTreeOnlyDefinitionsExceptAddChild() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: true),
        executionContext: KeymapExecutionContext(
            editingMode: .diagram,
            operationTargetKind: .node,
            hasFocusedNode: true
        )
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(ids.contains("addChildNode"))
    #expect(!ids.contains("addSiblingNodeAbove"))
    #expect(!ids.contains("addSiblingNodeBelow"))
    #expect(!ids.contains("duplicateSelectionAsSibling"))
    #expect(!ids.contains("toggleFoldFocusedSubtree"))
    #expect(ids.contains("beginConnectNodeSelection"))
}

@Test("ツリー コンテキストはダイアグラムのみのコマンドパレット定義を非表示にする")
func test_commandPaletteDefinitions_treeContext_hidesDiagramOnlyDefinitions() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: true),
        executionContext: KeymapExecutionContext(
            editingMode: .tree,
            operationTargetKind: .node,
            hasFocusedNode: true
        )
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

@Test("フォーカスのないコンテキストはフォーカスが必要なコマンドパレットの定義を非表示にする")
func test_commandPaletteDefinitions_withoutFocus_hidesFocusRequiredDefinitions() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: false),
        executionContext: KeymapExecutionContext(
            editingMode: .tree,
            operationTargetKind: .node,
            hasFocusedNode: false
        )
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(ids.contains("addNode"))
    #expect(ids.contains("addChildNode"))
    #expect(ids.contains("undo"))
    #expect(!ids.contains("deleteSelectedOrFocusedNodes"))
    #expect(!ids.contains("centerFocusedNode"))
}

@Test("エリア ターゲットは、ノード追加モードの選択を除き、ノード ターゲットのコマンドパレット定義を非表示にする")
func test_commandPaletteDefinitions_areaTarget_hidesNodeTargetDefinitionsExceptAddNodeModeSelection() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: true),
        executionContext: KeymapExecutionContext(
            editingMode: .tree,
            operationTargetKind: .area,
            hasFocusedNode: true
        )
    )
    let ids = Set(definitions.map(\.id.rawValue))

    #expect(ids.contains("addNode"))
    #expect(!ids.contains("addChildNode"))
    #expect(!ids.contains("moveNodeUp"))
    #expect(ids.contains("undo"))
}
