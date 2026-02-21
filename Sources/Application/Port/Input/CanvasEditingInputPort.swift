import Domain

public protocol CanvasEditingInputPort: Sendable {
    func apply(commands: [CanvasCommand]) async throws -> ApplyResult
    func addNodeFromModeSelection(mode: CanvasEditingMode) async throws -> ApplyResult
    func undo() async -> ApplyResult
    func redo() async -> ApplyResult
    func getCurrentResult() async -> ApplyResult
    func getCurrentGraph() async -> CanvasGraph
}

extension CanvasEditingInputPort {
    /// Default compatibility path: add node first, then move it into a mode-specific area when needed.
    public func addNodeFromModeSelection(mode: CanvasEditingMode) async throws -> ApplyResult {
        let addResult = try await apply(commands: [.addNode])
        guard addResult.didAddNode, let addedNodeID = addResult.newState.focusedNodeID else {
            return addResult
        }
        guard
            requiresModeSelectionAreaCreation(
                selectedMode: mode,
                addedNodeID: addedNodeID,
                in: addResult.newState
            )
        else {
            return addResult
        }

        let maximumRetryCount = 3
        var latestGraph = addResult.newState
        var retryCount = 0
        while retryCount <= maximumRetryCount {
            let areaID = nextAreaID(for: mode, in: latestGraph)
            do {
                let modeResult = try await apply(
                    commands: [.createArea(id: areaID, mode: mode, nodeIDs: [addedNodeID])]
                )
                return modeResultWithAddedNodeFlag(from: modeResult)
            } catch let error as CanvasAreaPolicyError {
                guard case .areaAlreadyExists = error else {
                    return modeResultWithAddedNodeFlag(from: await getCurrentResult())
                }
                latestGraph = await getCurrentGraph()
                retryCount += 1
            } catch {
                return modeResultWithAddedNodeFlag(from: await getCurrentResult())
            }
        }
        return modeResultWithAddedNodeFlag(from: await getCurrentResult())
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

    private func modeResultWithAddedNodeFlag(from result: ApplyResult) -> ApplyResult {
        ApplyResult(
            newState: result.newState,
            canUndo: result.canUndo,
            canRedo: result.canRedo,
            viewportIntent: result.viewportIntent,
            didAddNode: true
        )
    }
}
