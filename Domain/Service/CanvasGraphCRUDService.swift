// Background: Core graph editing must stay framework-agnostic and deterministic.
// Responsibility: Provide pure CRUD operations with invariant validation.
/// Pure domain service for immutable graph CRUD operations.
public enum CanvasGraphCRUDService {
    /// Inserts a node into the graph.
    /// - Parameters:
    ///   - node: Node to insert.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph containing the inserted node.
    /// - Throws: `CanvasGraphError` when invariants fail or ID already exists.
    public static func createNode(_ node: CanvasNode, in graph: CanvasGraph) throws -> CanvasGraph {
        try validate(node: node)
        guard graph.nodesByID[node.id] == nil else {
            throw CanvasGraphError.nodeAlreadyExists(node.id)
        }

        var nodes = graph.nodesByID
        nodes[node.id] = node
        return CanvasGraph(nodesByID: nodes, edgesByID: graph.edgesByID)
    }

    /// Reads a node by identifier.
    /// - Parameters:
    ///   - id: Target node ID.
    ///   - graph: Source graph snapshot.
    /// - Returns: Matching node, or `nil` when missing.
    public static func readNode(id: CanvasNodeID, in graph: CanvasGraph) -> CanvasNode? {
        graph.nodesByID[id]
    }

    /// Replaces an existing node.
    /// - Parameters:
    ///   - node: New node value.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph containing the updated node.
    /// - Throws: `CanvasGraphError` when invariants fail or node is missing.
    public static func updateNode(_ node: CanvasNode, in graph: CanvasGraph) throws -> CanvasGraph {
        try validate(node: node)
        guard graph.nodesByID[node.id] != nil else {
            throw CanvasGraphError.nodeNotFound(node.id)
        }

        var nodes = graph.nodesByID
        nodes[node.id] = node
        return CanvasGraph(nodesByID: nodes, edgesByID: graph.edgesByID)
    }

    /// Deletes a node and all connected edges.
    /// - Parameters:
    ///   - id: Node identifier to remove.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph without the node and related edges.
    /// - Throws: `CanvasGraphError.nodeNotFound` when node is missing.
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

    /// Inserts an edge into the graph.
    /// - Parameters:
    ///   - edge: Edge to insert.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph containing the inserted edge.
    /// - Throws: `CanvasGraphError` when invariants fail or ID already exists.
    public static func createEdge(_ edge: CanvasEdge, in graph: CanvasGraph) throws -> CanvasGraph {
        try validate(edge: edge, in: graph)
        guard graph.edgesByID[edge.id] == nil else {
            throw CanvasGraphError.edgeAlreadyExists(edge.id)
        }

        var edges = graph.edgesByID
        edges[edge.id] = edge
        return CanvasGraph(nodesByID: graph.nodesByID, edgesByID: edges)
    }

    /// Reads an edge by identifier.
    /// - Parameters:
    ///   - id: Target edge ID.
    ///   - graph: Source graph snapshot.
    /// - Returns: Matching edge, or `nil` when missing.
    public static func readEdge(id: CanvasEdgeID, in graph: CanvasGraph) -> CanvasEdge? {
        graph.edgesByID[id]
    }

    /// Replaces an existing edge.
    /// - Parameters:
    ///   - edge: New edge value.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph containing the updated edge.
    /// - Throws: `CanvasGraphError` when invariants fail or edge is missing.
    public static func updateEdge(_ edge: CanvasEdge, in graph: CanvasGraph) throws -> CanvasGraph {
        guard graph.edgesByID[edge.id] != nil else {
            throw CanvasGraphError.edgeNotFound(edge.id)
        }
        try validate(edge: edge, in: graph)

        var edges = graph.edgesByID
        edges[edge.id] = edge
        return CanvasGraph(nodesByID: graph.nodesByID, edgesByID: edges)
    }

    /// Deletes an edge.
    /// - Parameters:
    ///   - id: Edge identifier to remove.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph without the target edge.
    /// - Throws: `CanvasGraphError.edgeNotFound` when edge is missing.
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
    /// Validates node invariants before insert/update.
    /// - Parameter node: Candidate node value.
    /// - Throws: `CanvasGraphError` when ID or bounds are invalid.
    fileprivate static func validate(node: CanvasNode) throws {
        if node.id.rawValue.isEmpty {
            throw CanvasGraphError.invalidNodeID
        }
        if node.bounds.width <= 0 || node.bounds.height <= 0 {
            throw CanvasGraphError.invalidNodeBounds
        }
    }

    /// Validates edge invariants before insert/update.
    /// - Parameters:
    ///   - edge: Candidate edge value.
    ///   - graph: Graph snapshot used for endpoint existence checks.
    /// - Throws: `CanvasGraphError` when ID or endpoints are invalid.
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
