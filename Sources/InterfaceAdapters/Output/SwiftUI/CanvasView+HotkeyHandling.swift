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
        switch action {
        case .openCommandPalette:
            openCommandPalette()
            return true
        case .openSearch:
            openSearch()
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
        switch action {
        case .apply(let commands):
            Task {
                await viewModel.apply(commands: commands)
            }
            return true
        case .beginConnectNodeSelection:
            presentConnectNodeSelectionIfPossible()
            return true
        case .presentAddNodeModeSelection:
            presentAddNodeModeSelectionPopup()
            return true
        case .reportUnsupportedIntent:
            return true
        }
    }
}
