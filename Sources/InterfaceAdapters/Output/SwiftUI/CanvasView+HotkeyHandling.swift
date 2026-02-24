// Background: CanvasView key-event closure grows quickly as input modes increase.
// Responsibility: Keep hotkey branching and connect-mode banner rendering outside the root view file.
import AppKit
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
            .background(.regularMaterial)
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
        if hotkeyTranslator.shouldPresentAddNodeModeSelection(event) {
            presentAddNodeModeSelectionPopup()
            return true
        }
        if hotkeyTranslator.shouldBeginConnectNodeSelection(event) {
            presentConnectNodeSelectionIfPossible()
            return true
        }
        if handleCompositeMoveHotkey(event) {
            return true
        }
        if hotkeyTranslator.shouldOpenCommandPalette(event) {
            openCommandPalette()
            return true
        }
        if hotkeyTranslator.shouldOpenSearch(event) {
            openSearch()
            return true
        }
        if let zoomAction = hotkeyTranslator.zoomAction(event) {
            applyZoom(action: zoomAction)
            return true
        }
        if let historyAction = hotkeyTranslator.historyAction(event) {
            Task {
                switch historyAction {
                case .undo:
                    await viewModel.undo()
                case .redo:
                    await viewModel.redo()
                }
            }
            return true
        }
        let commands = hotkeyTranslator.translate(event)
        guard !commands.isEmpty else {
            let displayNodesByID = Dictionary(uniqueKeysWithValues: displayNodes.map { ($0.id, $0) })
            return handleTypingInputStart(event, nodesByID: displayNodesByID)
        }
        // Returning true tells the capture view to stop responder-chain propagation.
        Task { await viewModel.apply(commands: commands) }
        return true
    }
}
