// Background: Edge-target interaction needs local state orchestration before domain-level edge commands are introduced.
// Responsibility: Handle node/edge target switching, edge focus movement, and edge-target state synchronization.
import Domain

extension CanvasView {
    struct EdgeTargetModelSyncState {
        let targetKind: KeymapSwitchTargetKindIntentVariant
        let focusedEdgeID: CanvasEdgeID?
        let selectedEdgeIDs: Set<CanvasEdgeID>
    }

    static func edgeTargetStateSyncedWithModel(
        currentTargetKind: KeymapSwitchTargetKindIntentVariant,
        modelFocusedEdgeID: CanvasEdgeID?,
        modelFocusedAreaID: CanvasAreaID?,
        modelSelectedEdgeIDs: Set<CanvasEdgeID>
    ) -> EdgeTargetModelSyncState {
        if let modelFocusedEdgeID {
            return EdgeTargetModelSyncState(
                targetKind: .edge,
                focusedEdgeID: modelFocusedEdgeID,
                selectedEdgeIDs: modelSelectedEdgeIDs
            )
        }
        if modelFocusedAreaID != nil {
            return EdgeTargetModelSyncState(
                targetKind: .area,
                focusedEdgeID: nil,
                selectedEdgeIDs: []
            )
        }

        guard currentTargetKind == .edge || currentTargetKind == .area else {
            return EdgeTargetModelSyncState(
                targetKind: currentTargetKind,
                focusedEdgeID: nil,
                selectedEdgeIDs: []
            )
        }
        return EdgeTargetModelSyncState(
            targetKind: .node,
            focusedEdgeID: nil,
            selectedEdgeIDs: []
        )
    }

    func synchronizeEdgeTargetStateFromViewModel() {
        let syncedState = Self.edgeTargetStateSyncedWithModel(
            currentTargetKind: operationTargetKind,
            modelFocusedEdgeID: viewModel.focusedEdgeID,
            modelFocusedAreaID: viewModel.focusedAreaID,
            modelSelectedEdgeIDs: viewModel.selectedEdgeIDs
        )
        operationTargetKind = syncedState.targetKind
        focusedEdgeID = syncedState.focusedEdgeID
        selectedEdgeIDs = syncedState.selectedEdgeIDs
        if operationTargetKind == .edge {
            synchronizeEdgeTargetState()
        }
    }

    func switchOperationTarget(to variant: KeymapSwitchTargetKindIntentVariant) {
        switch variant {
        case .cycle:
            switchOperationTarget(to: nextTargetKindForCycle())
        case .area:
            guard let areaID = currentFocusedAreaID() else {
                return
            }
            operationTargetKind = .area
            focusedEdgeID = nil
            selectedEdgeIDs = []
            Task {
                await viewModel.apply(commands: [.focusArea(areaID)])
            }
        case .node:
            operationTargetKind = .node
            focusedEdgeID = nil
            selectedEdgeIDs = []
            if let focusedNodeID = viewModel.focusedNodeID {
                Task {
                    await viewModel.apply(commands: [.focusNode(focusedNodeID)])
                }
            }
        case .edge:
            if operationTargetKind == .edge {
                operationTargetKind = .node
                focusedEdgeID = nil
                selectedEdgeIDs = []
                return
            }
            guard let focusedNodeID = viewModel.focusedNodeID else {
                return
            }
            guard viewModel.diagramNodeIDs.contains(focusedNodeID) else {
                return
            }
            guard let areaID = viewModel.areaIDByNodeID[focusedNodeID] else {
                return
            }
            let edges = edgeCandidates(in: areaID)
            guard !edges.isEmpty else {
                return
            }

            let initialFocusedEdgeID =
                edges.first(where: { $0.fromNodeID == focusedNodeID || $0.toNodeID == focusedNodeID })?.id
                ?? edges[0].id
            operationTargetKind = .edge
            focusedEdgeID = initialFocusedEdgeID
            selectedEdgeIDs = [initialFocusedEdgeID]
        }
    }

    private func nextTargetKindForCycle() -> KeymapSwitchTargetKindIntentVariant {
        switch operationTargetKind {
        case .node:
            if canSwitchToEdgeTarget() {
                return .edge
            }
            if currentFocusedAreaID() != nil {
                return .area
            }
            return .node
        case .edge:
            if currentFocusedAreaID() != nil {
                return .area
            }
            return .node
        case .area:
            return .node
        case .cycle:
            return .node
        }
    }

    private func canSwitchToEdgeTarget() -> Bool {
        guard let focusedNodeID = viewModel.focusedNodeID else {
            return false
        }
        guard viewModel.diagramNodeIDs.contains(focusedNodeID) else {
            return false
        }
        guard let areaID = viewModel.areaIDByNodeID[focusedNodeID] else {
            return false
        }
        return !edgeCandidates(in: areaID).isEmpty
    }

    func currentFocusedAreaID() -> CanvasAreaID? {
        if let focusedAreaID = viewModel.focusedAreaID, graphAreaHasVisibleNode(focusedAreaID) {
            return focusedAreaID
        }
        guard let focusedNodeID = viewModel.focusedNodeID else {
            return nil
        }
        guard let areaID = viewModel.areaIDByNodeID[focusedNodeID] else {
            return nil
        }
        return graphAreaHasVisibleNode(areaID) ? areaID : nil
    }

    private func graphAreaHasVisibleNode(_ areaID: CanvasAreaID) -> Bool {
        viewModel.nodes.contains { node in
            viewModel.areaIDByNodeID[node.id] == areaID
        }
    }

    func synchronizeEdgeTargetState() {
        guard operationTargetKind == .edge else {
            return
        }
        guard let focusedNodeID = viewModel.focusedNodeID else {
            operationTargetKind = .node
            focusedEdgeID = nil
            selectedEdgeIDs = []
            return
        }
        guard viewModel.diagramNodeIDs.contains(focusedNodeID) else {
            operationTargetKind = .node
            focusedEdgeID = nil
            selectedEdgeIDs = []
            return
        }
        guard let areaID = viewModel.areaIDByNodeID[focusedNodeID] else {
            operationTargetKind = .node
            focusedEdgeID = nil
            selectedEdgeIDs = []
            return
        }
        let edges = edgeCandidates(in: areaID)
        guard !edges.isEmpty else {
            operationTargetKind = .node
            focusedEdgeID = nil
            selectedEdgeIDs = []
            return
        }
        guard let focusedEdgeID, edges.contains(where: { $0.id == focusedEdgeID }) else {
            let nextFocusedEdgeID = edges[0].id
            self.focusedEdgeID = nextFocusedEdgeID
            selectedEdgeIDs = [nextFocusedEdgeID]
            return
        }
        selectedEdgeIDs = selectedEdgeIDs.intersection(Set(edges.map(\.id)))
        selectedEdgeIDs.insert(focusedEdgeID)
    }

    func handleEdgeTargetCommands(commands: [CanvasCommand]) -> Bool {
        guard operationTargetKind == .edge else {
            return false
        }
        guard commands.count == 1, let command = commands.first else {
            return true
        }
        switch command {
        case .moveFocus(let direction):
            moveEdgeFocus(direction: direction, extendsSelection: false)
            return true
        case .extendSelection(let direction):
            moveEdgeFocus(direction: direction, extendsSelection: true)
            return true
        case .deleteSelectedOrFocusedNodes:
            guard let deletionCommand = edgeDeletionCommandFromCurrentState() else {
                return true
            }
            Task {
                await viewModel.apply(commands: [deletionCommand])
            }
            return true
        case .cycleFocusedEdgeDirectionality:
            cycleFocusedEdgeDirectionalityIfPossible()
            return true
        default:
            return true
        }
    }

    func cycleFocusedEdgeDirectionalityIfPossible() {
        guard let command = edgeDirectionalityCycleCommandFromCurrentState() else {
            return
        }
        Task {
            await viewModel.apply(commands: [command])
        }
    }

    func moveEdgeFocus(direction: CanvasFocusDirection, extendsSelection: Bool) {
        guard let focusedNodeID = viewModel.focusedNodeID else {
            return
        }
        guard let areaID = viewModel.areaIDByNodeID[focusedNodeID] else {
            return
        }
        let edges = edgeCandidates(in: areaID)
        guard !edges.isEmpty else {
            return
        }
        let graph = CanvasGraph(
            nodesByID: Dictionary(uniqueKeysWithValues: viewModel.nodes.map { ($0.id, $0) }),
            edgesByID: Dictionary(uniqueKeysWithValues: edges.map { ($0.id, $0) })
        )
        let nextFocusedEdgeID = CanvasFocusNavigationService.nextFocusedEdgeID(
            in: graph,
            from: focusedEdgeID,
            moving: direction
        )
        guard let nextFocusedEdgeID else {
            return
        }
        focusedEdgeID = nextFocusedEdgeID
        if extendsSelection {
            selectedEdgeIDs.insert(nextFocusedEdgeID)
        } else {
            selectedEdgeIDs = [nextFocusedEdgeID]
        }
    }

    func edgeCandidates(in areaID: CanvasAreaID) -> [CanvasEdge] {
        viewModel.edges
            .filter { edge in
                viewModel.areaIDByNodeID[edge.fromNodeID] == areaID
                    && viewModel.areaIDByNodeID[edge.toNodeID] == areaID
            }
            .sorted { lhs, rhs in
                if lhs.fromNodeID.rawValue != rhs.fromNodeID.rawValue {
                    return lhs.fromNodeID.rawValue < rhs.fromNodeID.rawValue
                }
                if lhs.toNodeID.rawValue != rhs.toNodeID.rawValue {
                    return lhs.toNodeID.rawValue < rhs.toNodeID.rawValue
                }
                return lhs.id.rawValue < rhs.id.rawValue
            }
    }

    func edgeDeletionCommandFromCurrentState() -> CanvasCommand? {
        guard operationTargetKind == .edge else {
            return nil
        }
        guard
            let focusedNodeID = viewModel.focusedNodeID,
            let focusedEdgeID
        else {
            return nil
        }
        return Self.edgeDeletionCommand(
            focusedNodeID: focusedNodeID,
            focusedEdgeID: focusedEdgeID,
            selectedEdgeIDs: selectedEdgeIDs
        )
    }

    static func edgeDeletionCommand(
        focusedNodeID: CanvasNodeID,
        focusedEdgeID: CanvasEdgeID,
        selectedEdgeIDs: Set<CanvasEdgeID>
    ) -> CanvasCommand {
        .deleteSelectedOrFocusedEdges(
            focusedEdge: CanvasEdgeFocus(edgeID: focusedEdgeID, originNodeID: focusedNodeID),
            selectedEdgeIDs: selectedEdgeIDs
        )
    }

    func edgeDirectionalityCycleCommandFromCurrentState() -> CanvasCommand? {
        guard operationTargetKind == .edge else {
            return nil
        }
        guard
            let focusedNodeID = viewModel.focusedNodeID,
            let focusedEdgeID
        else {
            return nil
        }
        return Self.edgeDirectionalityCycleCommand(
            focusedNodeID: focusedNodeID,
            focusedEdgeID: focusedEdgeID,
            selectedEdgeIDs: selectedEdgeIDs
        )
    }

    static func edgeDirectionalityCycleCommand(
        focusedNodeID: CanvasNodeID,
        focusedEdgeID: CanvasEdgeID,
        selectedEdgeIDs: Set<CanvasEdgeID>
    ) -> CanvasCommand {
        .cycleFocusedEdgeDirectionality(
            focusedEdge: CanvasEdgeFocus(
                edgeID: focusedEdgeID,
                originNodeID: focusedNodeID
            ),
            selectedEdgeIDs: selectedEdgeIDs
        )
    }
}
