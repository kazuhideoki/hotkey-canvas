import Domain

public protocol CanvasEditingInputPort: Sendable {
    func apply(commands: [CanvasCommand]) async throws -> ApplyResult
    func undo() async -> ApplyResult
    func redo() async -> ApplyResult
    func getCurrentResult() async -> ApplyResult
    func getCurrentGraph() async -> CanvasGraph
}
