// Background: New declarative execution policy should evaluate independently of adapters.
// Responsibility: Verify condition semantics and context mapping behavior.
import Domain
import Testing

@Test("Policy resolver: always condition always enables")
func test_policyResolver_always_isEnabled() {
    let context = KeymapExecutionContext()

    #expect(KeymapExecutionPolicyResolver.isEnabled(.always, context: context))
}

@Test("Policy resolver: requires focused node")
func test_policyResolver_requiresFocusedNode_requiresFocus() {
    let focusedContext = KeymapExecutionContext(hasFocusedNode: true)
    let unfocusedContext = KeymapExecutionContext(hasFocusedNode: false)

    #expect(KeymapExecutionPolicyResolver.isEnabled(.requiresFocusedNode, context: focusedContext))
    #expect(!KeymapExecutionPolicyResolver.isEnabled(.requiresFocusedNode, context: unfocusedContext))
}

@Test("Policy resolver: target kind constraints")
func test_policyResolver_targetKinds_isEnabledOnlyForAllowedKinds() {
    let nodeContext = KeymapExecutionContext(operationTargetKind: .node)
    let edgeContext = KeymapExecutionContext(operationTargetKind: .edge)

    #expect(KeymapExecutionPolicyResolver.isEnabled(.targetKinds([.node]), context: nodeContext))
    #expect(!KeymapExecutionPolicyResolver.isEnabled(.targetKinds([.node]), context: edgeContext))
}

@Test("Policy resolver: required modes")
func test_policyResolver_requiredModes_isEnabledWhenModeMatches() {
    let treeContext = KeymapExecutionContext(editingMode: .tree)
    let diagramContext = KeymapExecutionContext(editingMode: .diagram)
    let missingModeContext = KeymapExecutionContext(editingMode: nil)

    #expect(KeymapExecutionPolicyResolver.isEnabled(.requiredModes([.tree]), context: treeContext))
    #expect(!KeymapExecutionPolicyResolver.isEnabled(.requiredModes([.tree]), context: diagramContext))
    #expect(!KeymapExecutionPolicyResolver.isEnabled(.requiredModes([.tree]), context: missingModeContext))
}

@Test("Policy resolver: disallowed modes")
func test_policyResolver_disallowedModes_blocksConfiguredModes() {
    let nodeContext = KeymapExecutionContext(editingMode: .tree)
    let diagramContext = KeymapExecutionContext(editingMode: .diagram)

    #expect(!KeymapExecutionPolicyResolver.isEnabled(.disallowedModes([.tree]), context: nodeContext))
    #expect(KeymapExecutionPolicyResolver.isEnabled(.disallowedModes([.tree]), context: diagramContext))
}

@Test("Policy resolver: not text editing")
func test_policyResolver_notTextEditing_rejectsWhenEditing() {
    #expect(
        KeymapExecutionPolicyResolver.isEnabled(.notTextEditing, context: KeymapExecutionContext(isEditingText: false)))
    #expect(
        !KeymapExecutionPolicyResolver.isEnabled(.notTextEditing, context: KeymapExecutionContext(isEditingText: true)))
}

@Test("Policy resolver: selection count condition")
func test_policyResolver_requiresSelectionCount_matchesBounds() {
    let exactlyOneNode = KeymapExecutionContext(selectedNodeCount: 1, selectedEdgeCount: 0)
    let twoNodes = KeymapExecutionContext(selectedNodeCount: 2, selectedEdgeCount: 1)
    let condition = KeymapExecutionCondition.requiresSelectionCount(
        KeymapExecutionSelectionCountCondition(minNodeCount: 1, maxNodeCount: 1)
    )

    #expect(KeymapExecutionPolicyResolver.isEnabled(condition, context: exactlyOneNode))
    #expect(!KeymapExecutionPolicyResolver.isEnabled(condition, context: twoNodes))
}

@Test("Policy resolver: modalIn and modalOut conditions")
func test_policyResolver_modalConditions_matchModalSnapshot() {
    let noModalContext = KeymapExecutionContext()
    let paletteContext = KeymapExecutionContext(isCommandPalettePresented: true)
    let nodeContext = KeymapExecutionContext(isEditingText: false, isCommandPalettePresented: true)

    #expect(
        KeymapExecutionPolicyResolver.isEnabled(
            .modalIn([.commandPalette]),
            context: paletteContext
        )
    )
    #expect(
        !KeymapExecutionPolicyResolver.isEnabled(
            .modalIn([.commandPalette]),
            context: noModalContext
        )
    )
    #expect(KeymapExecutionPolicyResolver.isEnabled(.modalOut([.commandPalette]), context: noModalContext))
    #expect(!KeymapExecutionPolicyResolver.isEnabled(.modalOut([.commandPalette]), context: paletteContext))
    #expect(
        KeymapExecutionPolicyResolver.isEnabled(
            .all([.modalIn([.commandPalette]), .notTextEditing]), context: nodeContext))
}

@Test("Policy resolver: definition execution condition maps from command palette visibility")
func test_policyResolver_definition_executionCondition_mapsFromVisibility() {
    let definition = CanvasShortcutDefinition(
        id: CanvasShortcutID(rawValue: "test"),
        commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Test", verb: "Focus"),
        gesture: CanvasShortcutGesture(key: .character("t"), modifiers: []),
        action: .apply(commands: [.centerFocusedNode]),
        shortcutLabel: "t",
        commandPaletteVisibility: .requiresFocusedNodeAndMode([.tree, .diagram])
    )
    let context = KeymapExecutionContext(editingMode: .tree, hasFocusedNode: true)
    let withoutFocus = KeymapExecutionContext(editingMode: .tree, hasFocusedNode: false)

    #expect(KeymapExecutionPolicyResolver.isEnabled(definition: definition, context: context))
    #expect(!KeymapExecutionPolicyResolver.isEnabled(definition: definition, context: withoutFocus))
}
