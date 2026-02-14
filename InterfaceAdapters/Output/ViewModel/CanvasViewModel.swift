import Application
import Combine
import Domain

@MainActor
public final class CanvasViewModel: ObservableObject {
    @Published public private(set) var nodes: [CanvasNode] = []
    @Published public private(set) var focusedNodeID: CanvasNodeID?

    private let inputPort: any CanvasEditingInputPort
    private var nextRequestID: UInt64 = 0
    private var latestDisplayedRequestID: UInt64 = 0

    public init(inputPort: any CanvasEditingInputPort) {
        self.inputPort = inputPort
    }

    public func onAppear() async {
        let requestIDAtStart = latestDisplayedRequestID
        let graph = await inputPort.getCurrentGraph()
        // Ignore stale snapshot when a newer apply() result has already been displayed.
        guard requestIDAtStart == latestDisplayedRequestID else {
            return
        }
        nodes = sortedNodes(in: graph)
        focusedNodeID = graph.focusedNodeID
    }

    public func apply(commands: [CanvasCommand]) async {
        guard !commands.isEmpty else {
            return
        }

        nextRequestID &+= 1
        let requestID = nextRequestID
        do {
            let result = try await inputPort.apply(commands: commands)
            // Only display results newer than the currently displayed request.
            guard requestID > latestDisplayedRequestID else {
                return
            }
            nodes = sortedNodes(in: result.newState)
            focusedNodeID = result.newState.focusedNodeID
            latestDisplayedRequestID = requestID
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
