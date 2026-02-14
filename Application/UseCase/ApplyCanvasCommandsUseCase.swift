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
<<<<<<< HEAD
=======

extension ApplyCanvasCommandsUseCase {
    private static let newNodeWidth: Double = 220
    private static let newNodeHeight: Double = 120
    private static let defaultNewNodeX: Double = 48
    private static let defaultNewNodeY: Double = 48
    private static let newNodeVerticalSpacing: Double = 24

    private func apply(command: CanvasCommand, to graph: CanvasGraph) throws -> CanvasGraph {
        switch command {
        case .addNode:
            let bounds = makeAvailableNewNodeBounds(in: graph)
            let node = CanvasNode(
                id: CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())"),
                kind: .text,
                text: nil,
                bounds: bounds
            )
            let graphWithNode = try CanvasGraphCRUDService.createNode(node, in: graph)
            return CanvasGraph(
                nodesByID: graphWithNode.nodesByID,
                edgesByID: graphWithNode.edgesByID,
                focusedNodeID: node.id
            )
        case .addChildNode:
            return try addChildNode(in: graph, requiresTopLevelParent: false)
        case .addSiblingNode:
            return try addSiblingNode(in: graph)
        case .moveFocus(let direction):
            return moveFocus(in: graph, direction: direction)
        case .focusNode(let nodeID):
            return focusNode(in: graph, nodeID: nodeID)
        case .deleteFocusedNode:
            return try deleteFocusedNode(in: graph)
        case .setNodeText(let nodeID, let text):
            return try setNodeText(in: graph, nodeID: nodeID, text: text)
        }
    }
}

extension ApplyCanvasCommandsUseCase {
    func makeAvailableNewNodeBounds(in graph: CanvasGraph) -> CanvasBounds {
        let focusedNode = graph.focusedNodeID.flatMap { graph.nodesByID[$0] }
        let startX = focusedNode?.bounds.x ?? Self.defaultNewNodeX
        let startY =
            if let focusedNode {
                focusedNode.bounds.y + focusedNode.bounds.height + Self.newNodeVerticalSpacing
            } else {
                Self.defaultNewNodeY
            }

        var candidate = CanvasBounds(
            x: startX,
            y: startY,
            width: Self.newNodeWidth,
            height: Self.newNodeHeight
        )
        let sortedNodes = sortedNodes(in: graph)
        while let overlappedNode = firstOverlappedNode(for: candidate, in: sortedNodes) {
            candidate = CanvasBounds(
                x: candidate.x,
                y: overlappedNode.bounds.y + overlappedNode.bounds.height + Self.newNodeVerticalSpacing,
                width: candidate.width,
                height: candidate.height
            )
        }
        return candidate
    }

    private func firstOverlappedNode(for candidate: CanvasBounds, in nodes: [CanvasNode]) -> CanvasNode? {
        nodes.first { node in
            boundsOverlap(candidate, node.bounds)
        }
    }

    private func boundsOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds) -> Bool {
        let lhsRight = lhs.x + lhs.width
        let rhsRight = rhs.x + rhs.width
        let lhsBottom = lhs.y + lhs.height
        let rhsBottom = rhs.y + rhs.height
        return lhs.x < rhsRight && lhsRight > rhs.x && lhs.y < rhsBottom && lhsBottom > rhs.y
    }

    private func addChildNode(in graph: CanvasGraph, requiresTopLevelParent: Bool) throws -> CanvasGraph {
        guard let parentID = graph.focusedNodeID else {
            return graph
        }
        guard let parentNode = graph.nodesByID[parentID] else {
            return graph
        }
        if requiresTopLevelParent && !isTopLevelParent(parentID, in: graph) {
            return graph
        }

        let childBounds = calculateChildBounds(for: parentNode, in: graph)
        let childNode = CanvasNode(
            id: CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())"),
            kind: .text,
            text: nil,
            bounds: childBounds
        )

        var graphWithChild = try CanvasGraphCRUDService.createNode(childNode, in: graph)
        let edge = CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-\(UUID().uuidString.lowercased())"),
            fromNodeID: parentID,
            toNodeID: childNode.id,
            relationType: .parentChild
        )
        graphWithChild = try CanvasGraphCRUDService.createEdge(edge, in: graphWithChild)

        return CanvasGraph(
            nodesByID: graphWithChild.nodesByID,
            edgesByID: graphWithChild.edgesByID,
            focusedNodeID: childNode.id
        )
    }

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

    private func isTopLevelParent(_ nodeID: CanvasNodeID, in graph: CanvasGraph) -> Bool {
        !graph.edgesByID.values.contains {
            $0.relationType == .parentChild && $0.toNodeID == nodeID
        }
    }

    private func calculateChildBounds(for parentNode: CanvasNode, in graph: CanvasGraph) -> CanvasBounds {
        let width = parentNode.bounds.width
        let height = parentNode.bounds.height
        let y = parentNode.bounds.y

        var x = parentNode.bounds.x + parentNode.bounds.width + Self.childHorizontalGap
        var candidate = CanvasBounds(x: x, y: y, width: width, height: height)

        while hasOverlappingNode(candidate, in: graph) {
            x += width + Self.childHorizontalGap
            candidate = CanvasBounds(x: x, y: y, width: width, height: height)
        }
        return candidate
    }

    private func hasOverlappingNode(_ bounds: CanvasBounds, in graph: CanvasGraph) -> Bool {
        graph.nodesByID.values.contains { existingNode in
            intersects(bounds, existingNode.bounds)
        }
    }

    private func intersects(_ lhs: CanvasBounds, _ rhs: CanvasBounds) -> Bool {
        let lhsRight = lhs.x + lhs.width
        let lhsBottom = lhs.y + lhs.height
        let rhsRight = rhs.x + rhs.width
        let rhsBottom = rhs.y + rhs.height

        return lhs.x < rhsRight
            && lhsRight > rhs.x
            && lhs.y < rhsBottom
            && lhsBottom > rhs.y
    }

}

extension ApplyCanvasCommandsUseCase {
    private static let childHorizontalGap: Double = 32
}

private struct FocusCandidate {
    let node: CanvasNode
    let axisDistance: Double
    let perpendicularDistance: Double
    let distance: Double
}
>>>>>>> main
