import Domain

public protocol CanvasEditingInputPort: Sendable {
    func apply(commands: [CanvasCommand]) async throws -> ApplyResult
    func getCurrentGraph() async -> CanvasGraph
}
