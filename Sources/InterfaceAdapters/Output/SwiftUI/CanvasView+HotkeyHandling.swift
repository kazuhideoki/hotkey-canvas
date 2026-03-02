// Background: CanvasView key-event closure grows quickly as input modes increase.
// Responsibility: Keep hotkey branching and connect-mode banner rendering outside the root view file.
import AppKit
import Application
import Domain
import SwiftUI

extension CanvasView {
    @ViewBuilder
    func connectNodeSelectionBanner() -> some View {
        if isConnectNodeSelectionActive() {
            VStack(spacing: 6) {
                Text("Connect Mode")
                    .font(.system(size: 14, weight: .semibold))
                Text("↑↓←→: Select target  ↩: Connect  ⎋: Cancel")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .systemSurface(styleSheet.overlay.connectBannerSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 18)
            .zIndex(11)
        }
    }

    func handleCanvasHotkeyEvent(_ event: NSEvent, displayNodes: [CanvasNode]) -> Bool {
        if isConnectNodeSelectionActive() {
            return handleConnectNodeSelectionHotkey(event)
        }
        if isAddNodeModePopupPresented {
            return handleAddNodeModePopupHotkey(event)
        }
        if handleCompositeMoveHotkey(event) {
            return true
        }

        guard let route = hotkeyTranslator.resolve(event) else {
            let displayNodesByID = Dictionary(uniqueKeysWithValues: displayNodes.map { ($0.id, $0) })
            return handleTypingInputStart(event, nodesByID: displayNodesByID)
        }

        switch route {
        case .global(let action):
            return handleGlobalRoute(action)
        case .primitive(let intent):
            let contextAction = keymapContextActionResolver.resolve(primitiveIntent: intent)
            return handlePrimitiveContextAction(contextAction)
        case .modal:
            return true
        }
    }
}

extension CanvasView {
    private func handleGlobalRoute(_ action: KeymapGlobalAction) -> Bool {
        if !Self.isActionEnabled(action, context: keymapExecutionContext()) {
            return true
        }
        switch action {
        case .openCommandPalette:
            openCommandPalette()
            return true
        case .openSearch:
            openSearch()
            return true
        case .beginConnectNodeSelection:
            presentConnectNodeSelectionIfPossible()
            return true
        case .undo:
            Task {
                await viewModel.undo()
            }
            return true
        case .redo:
            Task {
                await viewModel.redo()
            }
            return true
        case .zoomIn:
            applyZoom(action: .zoomIn)
            return true
        case .zoomOut:
            applyZoom(action: .zoomOut)
            return true
        case .centerFocusedNode:
            Task {
                await viewModel.apply(commands: [.centerFocusedNode])
            }
            return true
        }
    }

    private func handlePrimitiveContextAction(_ action: KeymapContextAction) -> Bool {
        if !Self.isActionEnabled(action, context: keymapExecutionContext()) {
            return true
        }
        switch action {
        case .apply(let commands):
            if handleEdgeTargetCommands(commands: commands) {
                return true
            }
            Task {
                await viewModel.apply(commands: commands)
            }
            return true
        case .switchTargetKind(let variant):
            switchOperationTarget(to: variant)
            return true
        case .cycleFocusedEdgeDirectionality:
            cycleFocusedEdgeDirectionalityIfPossible()
            return true
        case .presentAddNodeModeSelection:
            presentAddNodeModeSelectionPopup()
            return true
        case .reportUnsupportedIntent:
            return true
        }
    }

    static func isActionEnabled(_ action: KeymapGlobalAction, context: KeymapExecutionContext) -> Bool {
        guard
            let shortcutAction = Self.shortcutAction(for: action),
            let definition = CanvasShortcutCatalogService.definition(for: shortcutAction)
        else {
            return true
        }
        return KeymapExecutionPolicyResolver.isEnabled(definition: definition, context: context)
    }

    static func isActionEnabled(_ action: KeymapContextAction, context: KeymapExecutionContext) -> Bool {
        switch action {
        case .apply(let commands):
            return commands.allSatisfy { command in
                isCommandEnabled(command, context: context)
            }
        case .switchTargetKind, .reportUnsupportedIntent:
            return true
        case .cycleFocusedEdgeDirectionality, .presentAddNodeModeSelection:
            return context.operationTargetKind != .area
        }
    }

    private static func shortcutAction(for action: KeymapGlobalAction) -> CanvasShortcutAction? {
        switch action {
        case .openCommandPalette:
            return .openCommandPalette
        case .openSearch:
            return nil
        case .beginConnectNodeSelection:
            return .beginConnectNodeSelection
        case .undo:
            return .undo
        case .redo:
            return .redo
        case .zoomIn:
            return .zoomIn
        case .zoomOut:
            return .zoomOut
        case .centerFocusedNode:
            return .apply(commands: [.centerFocusedNode])
        }
    }

    private static func isCommandEnabled(
        _ command: CanvasCommand,
        context: KeymapExecutionContext
    ) -> Bool {
        guard let definition = CanvasShortcutCatalogService.definition(for: command) else {
            return true
        }
        return KeymapExecutionPolicyResolver.isEnabled(
            definition: definition,
            context: context
        )
    }

    private func keymapExecutionContext() -> KeymapExecutionContext {
        KeymapExecutionContext(
            editingMode: commandPaletteActiveEditingMode(),
            operationTargetKind: operationTargetKind,
            hasFocusedNode: viewModel.focusedNodeID != nil,
            isEditingText: editingContext != nil,
            isCommandPalettePresented: isCommandPalettePresented,
            isSearchPresented: isSearchPresented,
            isConnectNodeSelectionActive: isConnectNodeSelectionActive(),
            isAddNodePopupPresented: isAddNodeModePopupPresented,
            selectedNodeCount: viewModel.selectedNodeIDs.count,
            selectedEdgeCount: viewModel.selectedEdgeIDs.count
        )
    }
}
