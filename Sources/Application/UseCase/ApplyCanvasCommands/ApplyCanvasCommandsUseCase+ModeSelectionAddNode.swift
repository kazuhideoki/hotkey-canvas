import Domain

// Background: Shift+Enter mode selection must remain one user action with one undo step.
// Responsibility: Build one composite mutation that adds a node and applies selected mode assignment.
extension ApplyCanvasCommandsUseCase {
    /// Adds one node and reassigns it to a newly created area when selected mode differs.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - selectedMode: User-selected editing mode for the newly added node.
    /// - Returns: Composite mutation result represented as a single history entry.
    /// - Throws: Any area resolution or domain mutation error encountered during composition.
    func addNodeFromModeSelection(
        in graph: CanvasGraph,
        selectedMode: CanvasEditingMode
    ) throws -> CanvasMutationResult {
        try CanvasAreaMembershipService.validate(in: graph).get()
        let addTarget = try resolveAddTargetForModeSelection(in: graph, selectedMode: selectedMode)
        let addMutationResult = try addNode(in: addTarget.graph, areaID: addTarget.areaID)
        guard let addedNodeID = addMutationResult.graphAfterMutation.focusedNodeID else {
            return addMutationResult
        }
        guard
            requiresModeSelectionAreaCreation(
                selectedMode: selectedMode,
                addedNodeID: addedNodeID,
                in: addMutationResult.graphAfterMutation
            )
        else {
            return addMutationResult
        }

        let graphAfterModeAssignment = try CanvasAreaMembershipService.createArea(
            id: nextAreaID(for: selectedMode, in: addMutationResult.graphAfterMutation),
            mode: selectedMode,
            nodeIDs: [addedNodeID],
            in: addMutationResult.graphAfterMutation
        ).get()

        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: graphAfterModeAssignment,
            effects: addMutationResult.effects,
            areaLayoutSeedNodeID: addMutationResult.areaLayoutSeedNodeID
        )
    }

    private func resolveAddTargetForModeSelection(
        in graph: CanvasGraph,
        selectedMode: CanvasEditingMode
    ) throws -> AddNodeTarget {
        guard graph.nodesByID.isEmpty else {
            let areaID = try resolveAreaIDForAddNode(in: graph).get()
            return AddNodeTarget(graph: graph, areaID: areaID)
        }

        if let existingAreaID = preferredAreaIDForEmptyGraph(in: graph, selectedMode: selectedMode) {
            return AddNodeTarget(graph: graph, areaID: existingAreaID)
        }

        let createdAreaID = nextAreaID(for: selectedMode, in: graph)
        let graphWithCreatedArea = try CanvasAreaMembershipService.createArea(
            id: createdAreaID,
            mode: selectedMode,
            nodeIDs: [],
            in: graph
        ).get()
        return AddNodeTarget(graph: graphWithCreatedArea, areaID: createdAreaID)
    }

    private func preferredAreaIDForEmptyGraph(
        in graph: CanvasGraph,
        selectedMode: CanvasEditingMode
    ) -> CanvasAreaID? {
        switch selectedMode {
        case .tree:
            if graph.areasByID[.defaultTree] != nil {
                return .defaultTree
            }
        case .diagram:
            break
        }

        return graph.areasByID.values
            .filter { $0.editingMode == selectedMode }
            .map(\.id)
            .sorted(by: { $0.rawValue < $1.rawValue })
            .first
    }

    private func requiresModeSelectionAreaCreation(
        selectedMode: CanvasEditingMode,
        addedNodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> Bool {
        switch CanvasAreaMembershipService.areaID(containing: addedNodeID, in: graph) {
        case .success(let areaID):
            guard let area = graph.areasByID[areaID] else {
                return false
            }
            return area.editingMode != selectedMode
        case .failure:
            return false
        }
    }

    private func nextAreaID(for mode: CanvasEditingMode, in graph: CanvasGraph) -> CanvasAreaID {
        let prefix = mode == .diagram ? "diagram-area-" : "tree-area-"
        let existingAreaIDs = Set(graph.areasByID.keys.map(\.rawValue))
        var serial = 1
        while true {
            let candidate = "\(prefix)\(serial)"
            if existingAreaIDs.contains(candidate) == false {
                return CanvasAreaID(rawValue: candidate)
            }
            serial += 1
        }
    }

    private func resolveAreaIDForAddNode(in graph: CanvasGraph) -> Result<CanvasAreaID, CanvasAreaPolicyError> {
        if let focusedNodeID = graph.focusedNodeID, graph.nodesByID[focusedNodeID] != nil {
            return CanvasAreaMembershipService.areaID(containing: focusedNodeID, in: graph)
        }
        let sortedAreaIDs = graph.areasByID.keys.sorted(by: { $0.rawValue < $1.rawValue })
        if sortedAreaIDs.count == 1, let areaID = sortedAreaIDs.first {
            return .success(areaID)
        }
        if sortedAreaIDs.count > 1 {
            return .failure(.areaResolutionAmbiguousForAddNode)
        }
        return .failure(.focusedNodeNotFound)
    }
}

private struct AddNodeTarget {
    let graph: CanvasGraph
    let areaID: CanvasAreaID
}
