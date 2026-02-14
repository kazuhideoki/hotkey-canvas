import Domain

// Background: The use case owns command application sequencing and in-memory graph state updates.
// Responsibility: Coordinate command execution and expose the latest graph snapshot.
public actor ApplyCanvasCommandsUseCase: CanvasEditingInputPort {
    private var graph: CanvasGraph

    public init(initialGraph: CanvasGraph = .empty) {
        graph = initialGraph
    }

    public func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        for command in commands {
            nextGraph = try apply(command: command, to: nextGraph)
        }
        graph = nextGraph
        return ApplyResult(newState: nextGraph)
    }

    public func getCurrentGraph() async -> CanvasGraph {
        graph
    }
}
