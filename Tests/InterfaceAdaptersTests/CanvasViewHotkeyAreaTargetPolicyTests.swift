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
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.deleteSelectedOrFocusedNodes]), context: context))
    #expect(!CanvasView.isActionEnabled(.apply(commands: [.extendSelection(.up)]), context: context))
    #expect(CanvasView.isActionEnabled(.apply(commands: [.moveFocus(.up)]), context: context))
    #expect(CanvasView.isActionEnabled(.switchTargetKind(variant: .node), context: context))
    #expect(!CanvasView.isActionEnabled(.cycleFocusedEdgeDirectionality, context: context))
    #expect(!CanvasView.isActionEnabled(.presentAddNodeModeSelection, context: context))
}

@Test("Command palette filtering reuses execution policy in area target")
func test_areaTarget_commandPaletteFiltersByExecutionPolicy() {
    let paletteContext = CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: true)
    let keymapContext = KeymapExecutionContext(
        editingMode: .tree,
        operationTargetKind: .area,
        hasFocusedNode: true,
        selectedNodeCount: 1,
        selectedEdgeCount: 0
    )
    let rawIds = CanvasShortcutCatalogService.commandPaletteDefinitions(context: paletteContext).compactMap {
        KeymapExecutionPolicyResolver.isEnabled(definition: $0, context: keymapContext)
            ? $0.id.rawValue
            : nil
    }

    let visibleIds = Set(rawIds)
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
