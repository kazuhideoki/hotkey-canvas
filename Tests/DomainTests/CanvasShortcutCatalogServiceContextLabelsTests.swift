import Domain
import Testing

@Test("Shortcut catalog: tree context rewrites copy cut paste labels")
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

@Test("Shortcut catalog: diagram context rewrites copy cut paste and nudge labels")
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

@Test("Shortcut catalog: edge-aware route is attached to edge-target navigation commands")
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
