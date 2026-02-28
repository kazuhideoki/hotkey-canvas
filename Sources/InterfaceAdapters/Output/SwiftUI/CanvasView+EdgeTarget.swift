// Background: Edge-target interaction needs local state orchestration before domain-level edge commands are introduced.
// Responsibility: Handle node/edge target switching, edge focus movement, and edge-target state synchronization.
import Domain

extension CanvasView {
    func switchOperationTarget(to variant: KeymapSwitchTargetKindIntentVariant) {
        switch variant {
        case .node:
            operationTargetKind = .node
            focusedEdgeID = nil
            selectedEdgeIDs = []
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
                // cmd+l is an exception: when no edge can be focused, fallback to connect creation.
                presentConnectNodeSelectionIfPossible()
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
        default:
            return true
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
}
