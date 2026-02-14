import Application
import Combine
import Domain

@MainActor
public final class CanvasViewModel: ObservableObject {
    @Published public private(set) var nodes: [CanvasNode] = []

    private let inputPort: any CanvasEditingInputPort

    public init(inputPort: any CanvasEditingInputPort) {
        self.inputPort = inputPort
    }

    public func onAppear() async {
        let graph = await inputPort.getCurrentGraph()
        nodes = sortedNodes(in: graph)
    }

    public func apply(commands: [CanvasCommand]) async {
        guard !commands.isEmpty else {
            return
        }

        do {
            let result = try await inputPort.apply(commands: commands)
            nodes = sortedNodes(in: result.newState)
        } catch {
            // Keep current display state when command application fails.
        }
    }
}

extension CanvasViewModel {
    private func sortedNodes(in graph: CanvasGraph) -> [CanvasNode] {
        graph.nodesByID.values.sorted {
            if $0.bounds.y == $1.bounds.y {
                return $0.bounds.x < $1.bounds.x
            }
            return $0.bounds.y < $1.bounds.y
        }
    }
}
