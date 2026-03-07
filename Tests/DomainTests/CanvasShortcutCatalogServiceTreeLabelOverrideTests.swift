import Domain
import Testing

// Background: Tree-context command palette labels use subtree-specific wording for clipboard actions.
// Responsibility: Verify tree-context label overrides from the shortcut catalog.
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
