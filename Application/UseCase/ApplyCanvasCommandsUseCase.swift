import Domain

// Background: The use case owns command application sequencing and in-memory graph state updates.
// Responsibility: Coordinate command execution and expose the latest graph snapshot.
public actor ApplyCanvasCommandsUseCase: CanvasEditingInputPort {
    private var graph: CanvasGraph
    private var undoStack: [CanvasGraph]
    private var redoStack: [CanvasGraph]
    private let maxHistoryCount: Int

    public init(initialGraph: CanvasGraph = .empty, maxHistoryCount: Int = 100) {
        graph = initialGraph
        undoStack = []
        redoStack = []
        self.maxHistoryCount = max(0, maxHistoryCount)
    }

    public func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        for command in commands {
            nextGraph = try apply(command: command, to: nextGraph)
        }
        guard nextGraph != graph else {
            return makeApplyResult(newState: graph)
        }
        appendUndoSnapshot(graph)
        graph = nextGraph
        redoStack.removeAll(keepingCapacity: true)
        return makeApplyResult(newState: nextGraph)
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
    private func makeApplyResult(newState: CanvasGraph) -> ApplyResult {
        ApplyResult(
            newState: newState,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty
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
