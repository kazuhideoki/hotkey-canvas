// Background: Connect-node mode needs isolated UI and keyboard behavior to keep CanvasView maintainable.
// Responsibility: Manage connect-node selection state, visuals, and confirmation flow.
import AppKit
import Domain
import SwiftUI

extension CanvasView {
    func isConnectNodeSelectionActive() -> Bool {
        connectNodeSelectionSourceNodeID != nil
    }

    func isConnectNodeSelectionSourceNode(_ nodeID: CanvasNodeID) -> Bool {
        connectNodeSelectionSourceNodeID == nodeID
    }

    func isConnectNodeSelectionTargetNode(_ nodeID: CanvasNodeID) -> Bool {
        connectNodeSelectionTargetNodeID == nodeID
    }

    func connectNodeSelectionBorderColor(
        for nodeID: CanvasNodeID,
        isEditing: Bool,
        isFocused: Bool,
        isSelected: Bool
    ) -> Color {
        if isEditing {
            return styleColor(styleSheet.nodeChrome.connectSelectionEditingBorderColor)
        }
        if isConnectNodeSelectionTargetNode(nodeID) {
            return styleColor(styleSheet.nodeChrome.connectSelectionTargetBorderColor)
        }
        if isConnectNodeSelectionSourceNode(nodeID) {
            return styleColor(styleSheet.nodeChrome.connectSelectionSourceBorderColor)
        }
        if isFocused {
            return styleColor(styleSheet.nodeChrome.focusedBorderColor)
        }
<<<<<<< HEAD
        return styleColor(styleSheet.nodeChrome.defaultBorderColor)
=======
        if isSelected {
            return Color.accentColor.opacity(0.55)
        }
        return Color(nsColor: .separatorColor)
>>>>>>> main
    }

    func connectNodeSelectionBorderLineWidth(
        for nodeID: CanvasNodeID,
        isEditing: Bool,
        isFocused: Bool,
        isSelected: Bool
    ) -> CGFloat {
        if isEditing || isFocused || isSelected || isConnectNodeSelectionSourceNode(nodeID)
            || isConnectNodeSelectionTargetNode(nodeID)
        {
            return nodeTextStyle.focusedBorderLineWidth
        }
        return nodeTextStyle.borderLineWidth
    }

    func presentConnectNodeSelectionIfPossible() {
        guard !isAddNodeModePopupPresented else {
            return
        }
        guard connectNodeSelectionSourceNodeID == nil else {
            return
        }
        guard let sourceNodeID = viewModel.focusedNodeID else {
            return
        }
        guard viewModel.diagramNodeIDs.contains(sourceNodeID) else {
            return
        }
        guard let sourceAreaID = viewModel.areaIDByNodeID[sourceNodeID] else {
            return
        }
        let candidates = connectNodeSelectionCandidates(in: sourceAreaID, excluding: sourceNodeID)
        guard let initialTargetNodeID = candidates.first?.id else {
            return
        }

        connectNodeSelectionSourceNodeID = sourceNodeID
        connectNodeSelectionTargetNodeID = initialTargetNodeID
    }

    func dismissConnectNodeSelection() {
        connectNodeSelectionSourceNodeID = nil
        connectNodeSelectionTargetNodeID = nil
    }

    func handleConnectNodeSelectionHotkey(_ event: NSEvent) -> Bool {
        guard let action = connectNodeSelectionHotkeyResolver.action(for: event) else {
            // Keep connect-node selection modal while active.
            return true
        }

        switch action {
        case .moveSelection(let direction):
            moveConnectNodeSelection(direction: direction)
        case .confirmSelection:
            commitConnectNodeSelection()
        case .dismiss:
            dismissConnectNodeSelection()
        }
        return true
    }

    func synchronizeConnectNodeSelectionState() {
        guard let sourceNodeID = connectNodeSelectionSourceNodeID else {
            return
        }
        guard viewModel.diagramNodeIDs.contains(sourceNodeID) else {
            dismissConnectNodeSelection()
            return
        }
        guard viewModel.nodes.contains(where: { $0.id == sourceNodeID }) else {
            dismissConnectNodeSelection()
            return
        }
        guard let sourceAreaID = viewModel.areaIDByNodeID[sourceNodeID] else {
            dismissConnectNodeSelection()
            return
        }
        let candidates = connectNodeSelectionCandidates(in: sourceAreaID, excluding: sourceNodeID)
        guard !candidates.isEmpty else {
            dismissConnectNodeSelection()
            return
        }
        guard let targetNodeID = connectNodeSelectionTargetNodeID else {
            connectNodeSelectionTargetNodeID = candidates[0].id
            return
        }
        guard candidates.contains(where: { $0.id == targetNodeID }) else {
            connectNodeSelectionTargetNodeID = candidates[0].id
            return
        }
    }

    func moveConnectNodeSelection(direction: CanvasFocusDirection) {
        guard let sourceNodeID = connectNodeSelectionSourceNodeID else {
            return
        }
        guard let sourceAreaID = viewModel.areaIDByNodeID[sourceNodeID] else {
            dismissConnectNodeSelection()
            return
        }
        let candidates = connectNodeSelectionCandidates(in: sourceAreaID, excluding: sourceNodeID)
        guard !candidates.isEmpty else {
            dismissConnectNodeSelection()
            return
        }
        let nodesByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        let currentTargetNodeID = connectNodeSelectionTargetNodeID ?? candidates[0].id
        guard nodesByID[currentTargetNodeID] != nil else {
            connectNodeSelectionTargetNodeID = candidates[0].id
            return
        }

        let selectionGraph = CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: [:],
            focusedNodeID: currentTargetNodeID,
            selectedNodeIDs: [currentTargetNodeID]
        )
        guard
            let nextFocusedNodeID = CanvasFocusNavigationService.nextFocusedNodeID(
                in: selectionGraph,
                moving: direction
            )
        else {
            return
        }
        connectNodeSelectionTargetNodeID = nextFocusedNodeID
    }

    func commitConnectNodeSelection() {
        guard
            let sourceNodeID = connectNodeSelectionSourceNodeID,
            let targetNodeID = connectNodeSelectionTargetNodeID
        else {
            dismissConnectNodeSelection()
            return
        }
        dismissConnectNodeSelection()
        Task {
            await viewModel.apply(
                commands: [.connectNodes(fromNodeID: sourceNodeID, toNodeID: targetNodeID)]
            )
        }
    }

    func connectNodeSelectionCandidates(
        in areaID: CanvasAreaID,
        excluding sourceNodeID: CanvasNodeID
    ) -> [CanvasNode] {
        viewModel.nodes
            .filter { node in
                node.id != sourceNodeID && viewModel.areaIDByNodeID[node.id] == areaID
            }
            .sorted { lhs, rhs in
                if lhs.bounds.y != rhs.bounds.y {
                    return lhs.bounds.y < rhs.bounds.y
                }
                if lhs.bounds.x != rhs.bounds.x {
                    return lhs.bounds.x < rhs.bounds.x
                }
                return lhs.id.rawValue < rhs.id.rawValue
            }
    }
}
