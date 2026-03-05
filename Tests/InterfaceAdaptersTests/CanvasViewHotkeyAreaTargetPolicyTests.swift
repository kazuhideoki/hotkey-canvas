import Application
import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasView area target policy: disables global actions requiring node/edge target")
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

@Test("CanvasView area target policy: disables node/edge command actions")
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
    #expect(!CanvasView.isActionEnabled(.presentAddNodeModeSelection, context: context))
}

@Test("CanvasView hotkey policy: allows addChildNode in diagram node target")
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

@Test("CanvasView hotkey policy: allows addChildNode in diagram node target without focused node")
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

@Test("CanvasView hotkey policy: moveFocusAcrossAreasToRoot is disabled in edge target")
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

@Test("CanvasView hotkey policy: add-node actions are disabled in edge target")
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

@Test("CanvasView hotkey policy: tree add actions are disabled in edge target")
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

@Test("CanvasView hotkey policy: node transform actions are disabled in edge target")
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

@Test("CanvasView hotkey policy: clipboard actions are disabled in edge target")
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

@Test("CanvasView hotkey policy: moveArea is enabled only in area target")
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

@Test("CanvasView hotkey policy: non-shortcut command fallback respects edge restrictions")
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

@Test("Command palette filtering reuses execution policy in area target")
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

    #expect(!visibleIds.contains("addNode"))
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

@Test("Command palette filtering: addChildNode is visible in diagram node target")
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

@Test("Command palette filtering reuses execution policy in edge target")
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

@Test("Command palette apply routing: edge target delegates edge-specific apply commands")
func test_commandPaletteApplyRouting_edgeTarget_delegatesEdgeSpecificApplyCommands() {
    let command: CanvasCommand = .moveFocus(.up)
    let definition = CanvasShortcutCatalogService.definition(for: command)

    #expect(definition != nil)
    #expect(definition?.executionRoute == .edgeAware)
}

@Test("Command palette apply routing: edge target does not delegate generic node apply commands")
func test_commandPaletteApplyRouting_edgeTarget_doesNotDelegateGenericNodeApplyCommands() {
    let command: CanvasCommand = .addChildNode
    let definition = CanvasShortcutCatalogService.definition(for: command)

    #expect(definition != nil)
    #expect(definition?.executionRoute != .edgeAware)
}

@Test("Command palette apply routing: non-edge-aware commands stay direct")
func test_commandPaletteApplyRouting_nonEdgeAwareCommandsRemainDirect() {
    let command: CanvasCommand = .addSiblingNode(position: .below)
    let definition = CanvasShortcutCatalogService.definition(for: command)

    #expect(definition != nil)
    #expect(definition?.executionRoute == .direct)
}
