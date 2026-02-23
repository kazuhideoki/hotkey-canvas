import Domain

// Background: Shift+Enter mode selection must remain one user action with one undo step.
// Responsibility: Build one composite mutation that adds a node and applies selected mode assignment.
extension ApplyCanvasCommandsUseCase {
    /// Adds one node into a dedicated area for the selected mode.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - selectedMode: User-selected editing mode for the newly added node.
    /// - Returns: Composite mutation result represented as a single history entry.
    /// - Throws: Any area creation or domain mutation error encountered during composition.
    func addNodeFromModeSelection(
        in graph: CanvasGraph,
        selectedMode: CanvasEditingMode
    ) throws -> CanvasMutationResult {
        try CanvasAreaMembershipService.validate(in: graph).get()
        let addTarget = try resolveAddTargetForModeSelection(in: graph, selectedMode: selectedMode)
        let addMutationResult = try addNode(in: addTarget.graph, areaID: addTarget.areaID)

        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: addMutationResult.graphAfterMutation,
            effects: addMutationResult.effects,
            areaLayoutSeedNodeID: addMutationResult.areaLayoutSeedNodeID
        )
    }

    private func resolveAddTargetForModeSelection(
        in graph: CanvasGraph,
        selectedMode: CanvasEditingMode
    ) throws -> AddNodeTarget {
        guard graph.nodesByID.isEmpty else {
            let createdAreaID = nextAreaID(for: selectedMode, in: graph)
            let graphWithCreatedArea = try CanvasAreaMembershipService.createArea(
                id: createdAreaID,
                mode: selectedMode,
                nodeIDs: [],
                in: graph
            ).get()
            return AddNodeTarget(graph: graphWithCreatedArea, areaID: createdAreaID)
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
            if let defaultTreeArea = graph.areasByID[.defaultTree], defaultTreeArea.editingMode == .tree {
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

}

private struct AddNodeTarget {
    let graph: CanvasGraph
    let areaID: CanvasAreaID
}
