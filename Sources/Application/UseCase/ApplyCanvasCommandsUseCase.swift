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
        let sequenceResult = try runLegacyCommandSequenceWithMutationResults(
            commands: commands,
            from: graph
        )
        let nextGraph = sequenceResult.graph
        let pipelineResult = pipelineCoordinator.run(
            on: graph,
            mutationResults: sequenceResult.mutationResults
        )

        guard nextGraph != graph else {
            return makeApplyResult(newState: graph)
        }
        appendUndoSnapshot(graph)
        graph = nextGraph
        redoStack.removeAll(keepingCapacity: true)
        return makeApplyResult(newState: nextGraph, didAddNode: pipelineResult.didAddNode)
    }

    public func undo() async -> ApplyResult {
        guard let previousGraph = undoStack.popLast() else {
            return makeApplyResult(newState: graph)
        }
        appendRedoSnapshot(graph)
        graph = previousGraph
        return makeApplyResult(newState: previousGraph)
    }

    public func redo() async -> ApplyResult {
        guard let nextGraph = redoStack.popLast() else {
            return makeApplyResult(newState: graph)
        }
        appendUndoSnapshot(graph)
        graph = nextGraph
        return makeApplyResult(newState: nextGraph)
    }

    public func getCurrentResult() async -> ApplyResult {
        makeApplyResult(newState: graph)
    }

    public func getCurrentGraph() async -> CanvasGraph {
        graph
    }
}

extension ApplyCanvasCommandsUseCase {
    func runLegacyCommandSequenceWithMutationResults(
        commands: [CanvasCommand],
        from baseGraph: CanvasGraph
    ) throws -> (graph: CanvasGraph, mutationResults: [CanvasMutationResult]) {
        var nextGraph = baseGraph
        var mutationResults: [CanvasMutationResult] = []
        mutationResults.reserveCapacity(commands.count)

        for command in commands {
            let graphBeforeMutation = nextGraph
            nextGraph = try apply(command: command, to: nextGraph)
            mutationResults.append(
                CanvasMutationResult.classify(
                    command: command,
                    graphBeforeMutation: graphBeforeMutation,
                    graphAfterMutation: nextGraph
                )
            )
        }

        return (graph: nextGraph, mutationResults: mutationResults)
    }

    func runLegacyCommandSequence(
        commands: [CanvasCommand],
        from baseGraph: CanvasGraph
    ) throws -> CanvasGraph {
        try runLegacyCommandSequenceWithMutationResults(
            commands: commands,
            from: baseGraph
        ).graph
    }

    func runPipelineCommandSequence(
        commands: [CanvasCommand],
        from baseGraph: CanvasGraph
    ) throws -> CanvasPipelineResult {
        let sequenceResult = try runLegacyCommandSequenceWithMutationResults(
            commands: commands,
            from: baseGraph
        )
        return pipelineCoordinator.run(on: baseGraph, mutationResults: sequenceResult.mutationResults)
    }

    private func makeApplyResult(newState: CanvasGraph, didAddNode: Bool = false) -> ApplyResult {
        ApplyResult(
            newState: newState,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
            didAddNode: didAddNode
        )
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
