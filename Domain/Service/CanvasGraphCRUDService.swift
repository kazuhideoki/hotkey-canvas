public enum CanvasGraphCRUDService {
    public static func createNode(_ node: CanvasNode, in graph: CanvasGraph) throws -> CanvasGraph {
        try validate(node: node)
        guard graph.nodesByID[node.id] == nil else {
            throw CanvasGraphError.nodeAlreadyExists(node.id)
        }

        var nodes = graph.nodesByID
        nodes[node.id] = node
        return CanvasGraph(nodesByID: nodes, edgesByID: graph.edgesByID)
    }

    public static func readNode(id: CanvasNodeID, in graph: CanvasGraph) -> CanvasNode? {
        graph.nodesByID[id]
    }

    public static func updateNode(_ node: CanvasNode, in graph: CanvasGraph) throws -> CanvasGraph {
        try validate(node: node)
        guard graph.nodesByID[node.id] != nil else {
            throw CanvasGraphError.nodeNotFound(node.id)
        }

        var nodes = graph.nodesByID
        nodes[node.id] = node
        return CanvasGraph(nodesByID: nodes, edgesByID: graph.edgesByID)
    }

    public static func deleteNode(id: CanvasNodeID, in graph: CanvasGraph) throws -> CanvasGraph {
        guard graph.nodesByID[id] != nil else {
            throw CanvasGraphError.nodeNotFound(id)
        }

        var nodes = graph.nodesByID
        nodes.removeValue(forKey: id)
        let edges = graph.edgesByID.filter { _, edge in
            edge.fromNodeID != id && edge.toNodeID != id
        }

        return CanvasGraph(nodesByID: nodes, edgesByID: edges)
    }

    public static func createEdge(_ edge: CanvasEdge, in graph: CanvasGraph) throws -> CanvasGraph {
        try validate(edge: edge, in: graph)
        guard graph.edgesByID[edge.id] == nil else {
            throw CanvasGraphError.edgeAlreadyExists(edge.id)
        }

        var edges = graph.edgesByID
        edges[edge.id] = edge
        return CanvasGraph(nodesByID: graph.nodesByID, edgesByID: edges)
    }

    public static func readEdge(id: CanvasEdgeID, in graph: CanvasGraph) -> CanvasEdge? {
        graph.edgesByID[id]
    }

    public static func updateEdge(_ edge: CanvasEdge, in graph: CanvasGraph) throws -> CanvasGraph {
        guard graph.edgesByID[edge.id] != nil else {
            throw CanvasGraphError.edgeNotFound(edge.id)
        }
        try validate(edge: edge, in: graph)

        var edges = graph.edgesByID
        edges[edge.id] = edge
        return CanvasGraph(nodesByID: graph.nodesByID, edgesByID: edges)
    }

    public static func deleteEdge(id: CanvasEdgeID, in graph: CanvasGraph) throws -> CanvasGraph {
        guard graph.edgesByID[id] != nil else {
            throw CanvasGraphError.edgeNotFound(id)
        }

        var edges = graph.edgesByID
        edges.removeValue(forKey: id)
        return CanvasGraph(nodesByID: graph.nodesByID, edgesByID: edges)
    }
}

extension CanvasGraphCRUDService {
    fileprivate static func validate(node: CanvasNode) throws {
        if node.id.rawValue.isEmpty {
            throw CanvasGraphError.invalidNodeID
        }
        if node.bounds.width <= 0 || node.bounds.height <= 0 {
            throw CanvasGraphError.invalidNodeBounds
        }
    }

    fileprivate static func validate(edge: CanvasEdge, in graph: CanvasGraph) throws {
        if edge.id.rawValue.isEmpty {
            throw CanvasGraphError.invalidEdgeID
        }
        guard graph.nodesByID[edge.fromNodeID] != nil else {
            throw CanvasGraphError.edgeEndpointNotFound(edge.fromNodeID)
        }
        guard graph.nodesByID[edge.toNodeID] != nil else {
            throw CanvasGraphError.edgeEndpointNotFound(edge.toNodeID)
        }
    }
}
