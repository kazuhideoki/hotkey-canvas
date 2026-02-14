import Domain
import Foundation

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

extension ApplyCanvasCommandsUseCase {
    private func apply(command: CanvasCommand, to graph: CanvasGraph) throws -> CanvasGraph {
        switch command {
        case .addNode:
            // NOTE: Minimal bootstrap behavior for now.
            // Default node shape/position and ID generation should move to a Domain factory/service
            // when add-node variants (explicit position/kind/size) are introduced.
            let nodeCount = graph.nodesByID.count
            let offset = Double(nodeCount * 24)
            let node = CanvasNode(
                id: CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())"),
                kind: .text,
                text: nil,
                bounds: CanvasBounds(
                    x: 48 + offset,
                    y: 48 + offset,
                    width: 220,
                    height: 120
                )
            )
            return try CanvasGraphCRUDService.createNode(node, in: graph)
        }
    }
}
