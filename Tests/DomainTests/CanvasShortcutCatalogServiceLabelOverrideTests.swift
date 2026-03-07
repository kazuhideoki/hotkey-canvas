import Domain
import Testing

// Background: Command palette labels vary by editing context for clipboard and nudge actions.
// Responsibility: Verify diagram-context label overrides are applied by the shortcut catalog.
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
