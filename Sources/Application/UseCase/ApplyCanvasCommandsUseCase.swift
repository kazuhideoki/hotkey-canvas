import Domain

// Background: The use case owns command application sequencing and in-memory graph state updates.
// Responsibility: Coordinate command execution and expose the latest graph snapshot.
public actor ApplyCanvasCommandsUseCase: CanvasEditingInputPort {
    private var graph: CanvasGraph
    private var undoStack: [CanvasGraph]
    private var redoStack: [CanvasGraph]
    var treeClipboardState: CanvasTreeClipboardState
    private let maxHistoryCount: Int
    private let pipelineCoordinator: CanvasCommandPipelineCoordinator

    public init(initialGraph: CanvasGraph = .empty, maxHistoryCount: Int = 100) {
        graph = initialGraph
        undoStack = []
        redoStack = []
        treeClipboardState = .empty
        self.maxHistoryCount = max(0, maxHistoryCount)
        pipelineCoordinator = CanvasCommandPipelineCoordinator()
    }

    /// Applies commands in order, then commits snapshot/history only when graph mutation occurred.
    /// - Parameter commands: Command sequence from input adapters.
    /// - Returns: Latest graph state with undo/redo flags and optional viewport intent.
    public func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        let shouldCenterFocusedNode = commands.contains(.centerFocusedNode)
        let pipelineResult = try runPipelineCommandSequence(
            commands: commands,
            from: graph
        )
        let nextGraph = pipelineResult.graph
        let viewportIntent =
            shouldCenterFocusedNode && nextGraph.focusedNodeID != nil
            ? CanvasViewportIntent.resetManualPanOffset
            : pipelineResult.viewportIntent
        let graphDidMutate = nextGraph != graph

        guard graphDidMutate || shouldCenterFocusedNode else {
            return makeApplyResult(newState: graph)
        }
        guard graphDidMutate else {
            return makeApplyResult(
                newState: graph,
                viewportIntent: viewportIntent,
                didAddNode: pipelineResult.didAddNode
            )
        }

        appendUndoSnapshot(graph)
        graph = nextGraph
        redoStack.removeAll(keepingCapacity: true)
        return makeApplyResult(
            newState: nextGraph,
            viewportIntent: viewportIntent,
            didAddNode: pipelineResult.didAddNode
        )
    }

    /// Adds one node and applies mode-specific area assignment within a single undoable mutation.
    public func addNodeFromModeSelection(mode: CanvasEditingMode) async throws -> ApplyResult {
        let baseGraph = graph
        let mutationResult = try addNodeFromModeSelection(in: baseGraph, selectedMode: mode)
        let pipelineResult = pipelineCoordinator.run(
            on: baseGraph,
            mutationResults: [mutationResult]
        )
        let nextGraph = pipelineResult.graph
        let graphDidMutate = nextGraph != baseGraph
        guard graphDidMutate else {
            return makeApplyResult(
                newState: baseGraph,
                viewportIntent: pipelineResult.viewportIntent,
                didAddNode: false
            )
        }

        appendUndoSnapshot(baseGraph)
        graph = nextGraph
        redoStack.removeAll(keepingCapacity: true)
        return makeApplyResult(
            newState: nextGraph,
            viewportIntent: pipelineResult.viewportIntent,
            didAddNode: hasAddedNode(from: baseGraph, to: nextGraph)
        )
    }

    /// Restores the previous graph snapshot and records the current state for redo.
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

    /// Reapplies a reverted snapshot and records the current state for undo.
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

    /// Returns the current in-memory graph wrapped as an apply result contract.
    public func getCurrentResult() async -> ApplyResult {
        makeApplyResult(newState: graph)
    }

    /// Exposes raw graph state for read-only consumers that do not need apply metadata.
    public func getCurrentGraph() async -> CanvasGraph {
        graph
    }
}

/// In-memory clipboard state for internal tree copy/cut/paste phase.
enum CanvasTreeClipboardState: Equatable, Sendable {
    case empty
    case subtree(CanvasTreeClipboardPayload)
}

extension ApplyCanvasCommandsUseCase {
    /// Executes command mutation one-by-one and feeds each mutation into the coordinator pipeline.
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

    /// Builds a canonical no-op mutation result that keeps all stage effects disabled.
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

    /// Normalizes apply-return payload construction to keep use case exits consistent.
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

    /// Converts focus transitions into viewport policy intent.
    private func viewportIntentForFocusChange(
        from previousFocusedNodeID: CanvasNodeID?,
        to currentFocusedNodeID: CanvasNodeID?
    ) -> CanvasViewportIntent? {
        _ = previousFocusedNodeID
        _ = currentFocusedNodeID
        return nil
    }

    /// Pushes a snapshot to undo history and enforces history length limits.
    private func appendUndoSnapshot(_ snapshot: CanvasGraph) {
        guard maxHistoryCount > 0 else {
            return
        }
        undoStack.append(snapshot)
        trimHistoryIfNeeded(&undoStack)
    }

    /// Pushes a snapshot to redo history and enforces history length limits.
    private func appendRedoSnapshot(_ snapshot: CanvasGraph) {
        guard maxHistoryCount > 0 else {
            return
        }
        redoStack.append(snapshot)
        trimHistoryIfNeeded(&redoStack)
    }

    /// Trims oldest snapshots first so history capacity remains bounded.
    private func trimHistoryIfNeeded(_ stack: inout [CanvasGraph]) {
        let overflowCount = stack.count - maxHistoryCount
        guard overflowCount > 0 else {
            return
        }
        stack.removeFirst(overflowCount)
    }
}
