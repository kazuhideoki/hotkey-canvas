import Application
import Domain
import Testing

@testable import InterfaceAdapters

@Test("ノード/エッジターゲットを必要とするグローバルアクションを無効にする")
func test_areaTarget_isActionEnabled_disablesGlobalNodeOrEdgeActions() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .area,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 0
    )

    #expect(!CanvasView.isActionEnabled(.beginConnectNodeSelection, context: context))
    #expect(!CanvasView.isActionEnabled(.centerFocusedNode, context: context))
    #expect(CanvasView.isActionEnabled(.openCommandPalette, context: context))
    #expect(CanvasView.isActionEnabled(.undo, context: context))
}

@Test("command-l はフォーカス中のエリアを再調整するために再利用される")
func test_areaTarget_beginConnectAction_recentersFocusedAreaWhenAreaIsFocused() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .area,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 0
    )

    #expect(
        CanvasView.beginConnectAreaBehavior(
            context: context,
            focusedAreaID: CanvasAreaID(rawValue: "focused-area")
        )
            == .recenterFocusedArea
    )
    #expect(
        CanvasView.beginConnectAreaBehavior(
            context: context,
            focusedAreaID: nil
        )
            == .enterConnectMode
    )
}

@Test("command-l はエリアを再センタリングしない")
func test_nodeTarget_beginConnectAction_doesNotRecenterArea() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .node,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 0
    )

    #expect(
        CanvasView.beginConnectAreaBehavior(
            context: context,
            focusedAreaID: CanvasAreaID(rawValue: "focused-area")
        )
            == .enterConnectMode
    )
}

@Test("再センタは手動パンとカメラアンカーをリセットする")
func test_recenteredViewportState_resetsPanAndAnchor() {
    let state = CanvasView.recenteredViewportState()

    #expect(state.manualPanOffset == .zero)
    #expect(!state.hasInitializedCameraAnchor)
    #expect(state.cameraAnchorPoint == .zero)
}

@Test("ノード/エッジコマンドアクションを無効にする")
func test_areaTarget_isActionEnabled_disablesNodeOrEdgeCommands() {
    let context = KeymapExecutionContext(
        editingMode: .tree,
        operationTargetKind: .area,
        hasFocusedNode: true,
        selectedNodeCount: 2,
        selectedEdgeCount: 0
    )

    #expect(!CanvasView.isActionEnabled(.apply(commands: [.addNode]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.addChildNode]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.addSiblingNode(position: .below)]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.moveNode(.right)]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.nudgeNode(.left)]), context: context))
    #expect(CanvasView.isActionEnabled(.apply(commands: [.moveArea(.right)]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.deleteSelectedOrFocusedNodes]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.extendSelection(.up)]), context: context))
    #expect(CanvasView.isActionEnabled(.apply(commands: [.moveFocus(.up)]), context: context))
    #expect(CanvasView.isActionEnabled(.switchTargetKind(variant: .node), context: context))
    #expect(!CanvasView.isActionEnabled(.cycleFocusedEdgeDirectionality, context: context))
    #expect(CanvasView.isActionEnabled(.presentAddNodeModeSelection, context: context))
}

@Test("ダイアグラムノード ターゲットで addChildNode を許可する")
func test_hotkeyPolicy_addChildNodeEnabledInDiagramNodeTarget() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .node,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 0
    )

    #expect(CanvasView.isActionEnabled(.apply(commands: [.addChildNode]), context: context))
}

@Test("フォーカス中のノードのないダイアグラムノード ターゲットで addChildNode を許可する")
func test_hotkeyPolicy_addChildNodeEnabledInDiagramNodeTargetWithoutFocus() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .node,
        hasFocusedNode: false,
        selectedNodeCount: 0,
        selectedEdgeCount: 0
    )

    #expect(CanvasView.isActionEnabled(.apply(commands: [.addChildNode]), context: context))
}

@Test("moveFocusAcrossAreasToRoot はエッジ ターゲットで無効になっています")
func test_hotkeyPolicy_moveFocusAcrossAreasToRootDisabledInEdgeTarget() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 1
    )

    #expect(
        !CanvasView.isActionEnabled(
            .apply(commands: [.moveFocusAcrossAreasToRoot(.right)]),
            context: context
        )
    )
}

@Test("エッジターゲットではノード追加アクションが無効になっています")
func test_hotkeyPolicy_addNodeActionsDisabledInEdgeTarget() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 1
    )

    #expect(!CanvasView.isActionEnabled(.apply(commands: [.addNode]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.addChildNode]), context: context))
    #expect(!CanvasView.isActionEnabled(.presentAddNodeModeSelection, context: context))
}

@Test("エッジターゲットではツリー追加アクションが無効になっています")
func test_hotkeyPolicy_treeAddActionsDisabledInEdgeTarget() {
    let context = KeymapExecutionContext(
        editingMode: .tree,
        operationTargetKind: .edge,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 1
    )

    #expect(!CanvasView.isActionEnabled(.apply(commands: [.addSiblingNode(position: .above)]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.addSiblingNode(position: .below)]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.duplicateSelectionAsSibling]), context: context))
}

@Test("エッジ ターゲットではノード変換アクションが無効になっています")
func test_hotkeyPolicy_nodeTransformActionsDisabledInEdgeTarget() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 1
    )

    #expect(!CanvasView.isActionEnabled(.apply(commands: [.moveNode(.right)]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.nudgeNode(.right)]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.scaleSelectedNodes(.up)]), context: context))
}

@Test("エッジターゲットではクリップボードアクションが無効になっています")
func test_hotkeyPolicy_clipboardActionsDisabledInEdgeTarget() {
    let context = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 1
    )

    #expect(!CanvasView.isActionEnabled(.apply(commands: [.copySelectionOrFocusedSubtree]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.cutSelectionOrFocusedSubtree]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.pasteClipboardAtFocusedNode]), context: context))
}

@Test("moveAreaはエリア対象のみ有効である")
func test_hotkeyPolicy_moveAreaEnabledOnlyInAreaTarget() {
    let allowedContext = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .area,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 0
    )
    let deniedContext = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 1
    )

    #expect(CanvasView.isActionEnabled(.apply(commands: [.moveArea(.right)]), context: allowedContext))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.moveArea(.right)]), context: deniedContext))
}

@Test("非ショートカット コマンド フォールバックはエッジ制限を考慮する")
func test_hotkeyPolicy_nonShortcutCommandFallbackRespectsEdgeRestrictions() {
    let edgeContext = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .edge,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 1
    )
    let nodeContext = KeymapExecutionContext(
        editingMode: .diagram,
        operationTargetKind: .node,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 0
    )

    #expect(!CanvasView.isActionEnabled(.apply(commands: [.alignAllAreasVertically]), context: edgeContext))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.toggleFocusedNodeMarkdownStyle]), context: edgeContext))
    #expect(CanvasView.isActionEnabled(.apply(commands: [.alignAllAreasVertically]), context: nodeContext))
    #expect(CanvasView.isActionEnabled(.apply(commands: [.toggleFocusedNodeMarkdownStyle]), context: nodeContext))
}

@Test("コマンドパレットの絞り込みはエリア対象でも実行ポリシーを再利用する")
func test_areaTarget_commandPaletteFiltersByExecutionPolicy() {
    let paletteContext = CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: true)
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: paletteContext,
        executionContext: KeymapExecutionContext(
            editingMode: .tree,
            operationTargetKind: .area,
            hasFocusedNode: true,
            selectedNodeCount: 1,
            selectedEdgeCount: 0
        )
    )
    let visibleIds = Set(definitions.map(\.id.rawValue))

    #expect(visibleIds.contains("addNode"))
    #expect(!visibleIds.contains("addChildNode"))
    #expect(!visibleIds.contains("addSiblingNodeAbove"))
    #expect(!visibleIds.contains("addSiblingNodeBelow"))
    #expect(!visibleIds.contains("deleteSelectedOrFocusedNodes"))
    #expect(!visibleIds.contains("extendSelectionUp"))
    #expect(!visibleIds.contains("moveNodeUp"))
    #expect(!visibleIds.contains("scaleSelectedNodesUp.commandOptionPlus"))
    #expect(!visibleIds.contains("centerFocusedNode"))
    #expect(visibleIds.contains("undo"))
}

@Test("addChildNode はダイアグラムノード ターゲットに表示される")
func test_diagramNodeTarget_commandPaletteShowsAddChildNode() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: false),
        executionContext: KeymapExecutionContext(
            editingMode: .diagram,
            operationTargetKind: .node,
            hasFocusedNode: false
        )
    )
    let visibleIds = Set(definitions.map(\.id.rawValue))

    #expect(visibleIds.contains("addChildNode"))
    #expect(!visibleIds.contains("addSiblingNodeAbove"))
    #expect(!visibleIds.contains("addSiblingNodeBelow"))
}

@Test("コマンドパレットの絞り込みはエッジ対象でも実行ポリシーを再利用する")
func test_edgeTarget_commandPaletteFiltersByExecutionPolicy() {
    let paletteContext = CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: true)
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: paletteContext,
        executionContext: KeymapExecutionContext(
            editingMode: .tree,
            operationTargetKind: .edge,
            hasFocusedNode: true,
            selectedNodeCount: 1,
            selectedEdgeCount: 1
        )
    )
    let visibleIds = Set(definitions.map(\.id.rawValue))

    #expect(!visibleIds.contains("addNode"))
    #expect(!visibleIds.contains("addChildNode"))
    #expect(!visibleIds.contains("addSiblingNodeAbove"))
    #expect(!visibleIds.contains("addSiblingNodeBelow"))
    #expect(!visibleIds.contains("copySelectionOrFocusedSubtree"))
    #expect(!visibleIds.contains("cutSelectionOrFocusedSubtree"))
    #expect(!visibleIds.contains("pasteClipboardAtFocusedNode"))
    #expect(!visibleIds.contains("moveNodeUp"))
    #expect(!visibleIds.contains("nudgeNodeUp"))
    #expect(!visibleIds.contains("scaleSelectedNodesUp.commandOptionPlus"))
}

@Test("エッジターゲットはエッジ固有の適用コマンドを委任する")
func test_commandPaletteApplyRouting_edgeTarget_delegatesEdgeSpecificApplyCommands() {
    let command: CanvasCommand = .moveFocus(.up)
    let definition = CanvasShortcutCatalogService.definition(for: command)

    #expect(definition != nil)
    #expect(definition?.executionRoute == .edgeAware)
}

@Test("エッジ ターゲットは汎用ノード適用コマンドを委任しない")
func test_commandPaletteApplyRouting_edgeTarget_doesNotDelegateGenericNodeApplyCommands() {
    let command: CanvasCommand = .addChildNode
    let definition = CanvasShortcutCatalogService.definition(for: command)

    #expect(definition != nil)
    #expect(definition?.executionRoute != .edgeAware)
}

@Test("非エッジ対応コマンドは直接的なままである")
func test_commandPaletteApplyRouting_nonEdgeAwareCommandsRemainDirect() {
    let command: CanvasCommand = .addSiblingNode(position: .below)
    let definition = CanvasShortcutCatalogService.definition(for: command)

    #expect(definition != nil)
    #expect(definition?.executionRoute == .direct)
}
