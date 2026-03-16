import Domain
import Testing

@Test("ツリーコンテキストの書き換えラベルのコピー、カット、ペースト")
func test_commandPaletteDefinitions_treeContext_rewritesClipboardLabels() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: true),
        executionContext: KeymapExecutionContext(
            editingMode: .tree,
            operationTargetKind: .node,
            hasFocusedNode: true
        )
    )
    let titleByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id.rawValue, $0.title) })

    #expect(titleByID["deleteSelectedOrFocusedNodes"] == "Node: Delete Selected")
    #expect(titleByID["copySelectionOrFocusedSubtree"] == "Node: Copy Selected & Subtree")
    #expect(titleByID["cutSelectionOrFocusedSubtree"] == "Node: Cut Selected & Subtree")
    #expect(titleByID["pasteClipboardAtFocusedNode"] == "Node: Paste As Child")
}

@Test("図のコンテキストを書き換え、コピー、カット、ペースト、ラベルのナッジを行う")
func test_commandPaletteDefinitions_diagramContext_rewritesClipboardAndNudgeLabels() {
    let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions(
        context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: true),
        executionContext: KeymapExecutionContext(
            editingMode: .diagram,
            operationTargetKind: .node,
            hasFocusedNode: true
        )
    )
    let titleByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id.rawValue, $0.title) })

    #expect(titleByID["deleteSelectedOrFocusedNodes"] == "Node: Delete Selected")
    #expect(titleByID["copySelectionOrFocusedSubtree"] == "Node: Copy Selected")
    #expect(titleByID["cutSelectionOrFocusedSubtree"] == "Node: Cut Selected")
    #expect(titleByID["pasteClipboardAtFocusedNode"] == "Node: Paste")
    #expect(titleByID["nudgeNodeUp"] == "Node: Move Up Slightly")
}

@Test("エッジ認識ルートはエッジターゲットナビゲーションコマンドに付加される")
func test_commandPaletteDefinitions_attachEdgeAwareRouteToEdgeNavigationCommands() {
    let moveFocus = CanvasShortcutCatalogService.definition(for: .moveFocus(.up))
    let extendSelection = CanvasShortcutCatalogService.definition(for: .extendSelection(.left))
    let deleteSelected = CanvasShortcutCatalogService.definition(for: .deleteSelectedOrFocusedNodes)

    #expect(moveFocus != nil)
    #expect(extendSelection != nil)
    #expect(deleteSelected != nil)
    #expect(moveFocus?.executionRoute == .edgeAware)
    #expect(extendSelection?.executionRoute == .edgeAware)
    #expect(deleteSelected?.executionRoute == .edgeAware)
}
