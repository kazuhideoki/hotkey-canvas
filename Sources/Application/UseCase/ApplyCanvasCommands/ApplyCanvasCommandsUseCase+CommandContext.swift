import Domain

// Background: Dispatch needs a resolved command, area, and execution context before mutation begins.
// Responsibility: Define dispatch context and target-kind resolution helpers.
extension ApplyCanvasCommandsUseCase {
    struct CommandDispatchContext {
        let command: CanvasCommand
        let area: CanvasArea
        let executionContext: KeymapExecutionContext
    }

    func operationTargetKind(
        for command: CanvasCommand,
        in graph: CanvasGraph,
        editingMode: CanvasEditingMode
    ) -> KeymapSwitchTargetKindIntentVariant {
        if case .edge = graph.focusedElement {
            return .edge
        }

        switch command {
        case .deleteSelectedOrFocusedEdges, .cycleFocusedEdgeDirectionality, .setEdgeLabel:
            return .edge
        case .focusArea:
            return .area
        default:
            guard case .area = graph.focusedElement else {
                return .node
            }
            guard let definition = CanvasShortcutCatalogService.definition(for: command) else {
                return .area
            }
            let areaContext = KeymapExecutionContext(
                editingMode: editingMode,
                operationTargetKind: .area,
                hasFocusedNode: graph.focusedNodeID != nil,
                isEditingText: false,
                isCommandPalettePresented: false,
                isSearchPresented: false,
                isConnectNodeSelectionActive: false,
                isAddNodePopupPresented: false,
                selectedNodeCount: graph.selectedNodeIDs.count,
                selectedEdgeCount: graph.selectedEdgeIDs.count
            )
            if KeymapExecutionPolicyResolver.isEnabled(
                definition: definition,
                context: areaContext
            ) {
                return .area
            }
            return .node
        }
    }
}
