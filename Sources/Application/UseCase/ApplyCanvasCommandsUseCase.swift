import Domain

// Background: The use case owns command application sequencing and in-memory graph state updates.
// Responsibility: Coordinate command execution and expose the latest graph snapshot.
public actor ApplyCanvasCommandsUseCase: CanvasEditingInputPort {
    private var graph: CanvasGraph
    private var undoStack: [CanvasGraph]
    private var redoStack: [CanvasGraph]
    private let maxHistoryCount: Int
    private let pipelineCoordinator: CanvasCommandPipelineCoordinator

    public init(initialGraph: CanvasGraph = .empty, maxHistoryCount: Int = 100) {
        graph = initialGraph
        undoStack = []
        redoStack = []
        self.maxHistoryCount = max(0, maxHistoryCount)
        pipelineCoordinator = CanvasCommandPipelineCoordinator()
    }

    public func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        let pipelineResult = try runPipelineCommandSequence(
            commands: commands,
            from: graph
        )
        let nextGraph = pipelineResult.graph

        guard nextGraph != graph else {
            return makeApplyResult(newState: graph)
        }
        appendUndoSnapshot(graph)
        graph = nextGraph
        redoStack.removeAll(keepingCapacity: true)
        return makeApplyResult(
            newState: nextGraph,
            viewportIntent: pipelineResult.viewportIntent,
            didAddNode: pipelineResult.didAddNode
        )
    }

    public func undo() async -> ApplyResult {
        guard let previousGraph = undoStack.popLast() else {
            return makeApplyResult(newState: graph)
        }
        let graphBeforeUndo = graph
        appendRedoSnapshot(graph)
        graph = previousGraph
        return makeApplyResult(
            newState: previousGraph,
            viewportIntent: viewportIntentForFocusChange(
                from: graphBeforeUndo.focusedNodeID,
                to: previousGraph.focusedNodeID
            )
        )
    }

    public func redo() async -> ApplyResult {
        guard let nextGraph = redoStack.popLast() else {
            return makeApplyResult(newState: graph)
        }
        let graphBeforeRedo = graph
        appendUndoSnapshot(graph)
        graph = nextGraph
        return makeApplyResult(
            newState: nextGraph,
            viewportIntent: viewportIntentForFocusChange(
                from: graphBeforeRedo.focusedNodeID,
                to: nextGraph.focusedNodeID
            )
        )
    }

    public func getCurrentResult() async -> ApplyResult {
        makeApplyResult(newState: graph)
    }

    public func getCurrentGraph() async -> CanvasGraph {
        graph
    }
}

extension ApplyCanvasCommandsUseCase {
    func runPipelineCommandSequence(
        commands: [CanvasCommand],
        from baseGraph: CanvasGraph
    ) throws -> CanvasPipelineResult {
        var nextGraph = baseGraph
        var lastViewportIntent: CanvasViewportIntent?

        for command in commands {
            let mutationResult = try applyMutation(command: command, to: nextGraph)
            let stepResult = pipelineCoordinator.run(
                on: nextGraph,
                mutationResults: [mutationResult]
            )
            nextGraph = stepResult.graph
            if let viewportIntent = stepResult.viewportIntent {
                lastViewportIntent = viewportIntent
            }
        }

        return CanvasPipelineResult(
            graph: nextGraph,
            viewportIntent: lastViewportIntent,
            didAddNode: hasAddedNode(from: baseGraph, to: nextGraph)
        )
    }

    func noOpMutationResult(for graph: CanvasGraph) -> CanvasMutationResult {
        CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: graph,
            effects: .noEffect
        )
    }

    private func hasAddedNode(from oldGraph: CanvasGraph, to newGraph: CanvasGraph) -> Bool {
        let previousNodeIDs = Set(oldGraph.nodesByID.keys)
        return newGraph.nodesByID.keys.contains { !previousNodeIDs.contains($0) }
    }

    private func makeApplyResult(
        newState: CanvasGraph,
        viewportIntent: CanvasViewportIntent? = nil,
        didAddNode: Bool = false
    ) -> ApplyResult {
        ApplyResult(
            newState: newState,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
            viewportIntent: viewportIntent,
            didAddNode: didAddNode
        )
    }

    private func viewportIntentForFocusChange(
        from previousFocusedNodeID: CanvasNodeID?,
        to currentFocusedNodeID: CanvasNodeID?
    ) -> CanvasViewportIntent? {
        _ = previousFocusedNodeID
        _ = currentFocusedNodeID
        return nil
    }

    private func appendUndoSnapshot(_ snapshot: CanvasGraph) {
        guard maxHistoryCount > 0 else {
            return
        }
        undoStack.append(snapshot)
        trimHistoryIfNeeded(&undoStack)
    }

    private func appendRedoSnapshot(_ snapshot: CanvasGraph) {
        guard maxHistoryCount > 0 else {
            return
        }
        redoStack.append(snapshot)
        trimHistoryIfNeeded(&redoStack)
    }

    private func trimHistoryIfNeeded(_ stack: inout [CanvasGraph]) {
        let overflowCount = stack.count - maxHistoryCount
        guard overflowCount > 0 else {
            return
        }
        stack.removeFirst(overflowCount)
    }
}
