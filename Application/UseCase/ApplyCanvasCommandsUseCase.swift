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
            let graphWithNode = try CanvasGraphCRUDService.createNode(node, in: graph)
            return CanvasGraph(
                nodesByID: graphWithNode.nodesByID,
                edgesByID: graphWithNode.edgesByID,
                focusedNodeID: node.id
            )
        case .moveFocus(let direction):
            return moveFocus(in: graph, direction: direction)
        }
    }
}

extension ApplyCanvasCommandsUseCase {
    private func moveFocus(in graph: CanvasGraph, direction: CanvasFocusDirection) -> CanvasGraph {
        let sortedNodes = sortedNodes(in: graph)
        guard !sortedNodes.isEmpty else {
            return graph
        }

        let fallbackNode = sortedNodes[0]
        let currentNode = graph.focusedNodeID.flatMap { graph.nodesByID[$0] } ?? fallbackNode

        let candidate =
            sortedNodes
            .filter { $0.id != currentNode.id }
            .compactMap { makeFocusCandidate(to: $0, from: currentNode, direction: direction) }
            .min(by: isBetterFocusCandidate)

        guard let nextNode = candidate?.node else {
            guard graph.focusedNodeID != currentNode.id else {
                return graph
            }
            return CanvasGraph(
                nodesByID: graph.nodesByID,
                edgesByID: graph.edgesByID,
                focusedNodeID: currentNode.id
            )
        }
        return CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nextNode.id
        )
    }

    private func sortedNodes(in graph: CanvasGraph) -> [CanvasNode] {
        graph.nodesByID.values.sorted { lhs, rhs in
            if lhs.bounds.y == rhs.bounds.y {
                return lhs.bounds.x < rhs.bounds.x
            }
            return lhs.bounds.y < rhs.bounds.y
        }
    }

    private func makeFocusCandidate(
        to node: CanvasNode,
        from currentNode: CanvasNode,
        direction: CanvasFocusDirection
    ) -> FocusCandidate? {
        let currentCenter = nodeCenter(for: currentNode)
        let nodeCenter = nodeCenter(for: node)
        let deltaX = nodeCenter.x - currentCenter.x
        let deltaY = nodeCenter.y - currentCenter.y
        let axisDistance = axisDistanceForDirection(deltaX: deltaX, deltaY: deltaY, direction: direction)
        guard axisDistance > 0 else {
            return nil
        }
        let perpendicularDistance = perpendicularDistanceForDirection(
            deltaX: deltaX,
            deltaY: deltaY,
            direction: direction
        )
        let distance = (deltaX * deltaX) + (deltaY * deltaY)
        return FocusCandidate(
            node: node,
            axisDistance: axisDistance,
            perpendicularDistance: perpendicularDistance,
            distance: distance
        )
    }

    private func nodeCenter(for node: CanvasNode) -> (x: Double, y: Double) {
        (
            x: node.bounds.x + (node.bounds.width / 2),
            y: node.bounds.y + (node.bounds.height / 2)
        )
    }

    private func axisDistanceForDirection(
        deltaX: Double,
        deltaY: Double,
        direction: CanvasFocusDirection
    ) -> Double {
        switch direction {
        case .up:
            return -deltaY
        case .down:
            return deltaY
        case .left:
            return -deltaX
        case .right:
            return deltaX
        }
    }

    private func perpendicularDistanceForDirection(
        deltaX: Double,
        deltaY: Double,
        direction: CanvasFocusDirection
    ) -> Double {
        switch direction {
        case .up, .down:
            return abs(deltaX)
        case .left, .right:
            return abs(deltaY)
        }
    }

    private func isBetterFocusCandidate(_ lhs: FocusCandidate, _ rhs: FocusCandidate) -> Bool {
        if lhs.axisDistance != rhs.axisDistance {
            return lhs.axisDistance < rhs.axisDistance
        }
        if lhs.perpendicularDistance != rhs.perpendicularDistance {
            return lhs.perpendicularDistance < rhs.perpendicularDistance
        }
        if lhs.distance != rhs.distance {
            return lhs.distance < rhs.distance
        }
        return lhs.node.id.rawValue < rhs.node.id.rawValue
    }
}

private struct FocusCandidate {
    let node: CanvasNode
    let axisDistance: Double
    let perpendicularDistance: Double
    let distance: Double
}
