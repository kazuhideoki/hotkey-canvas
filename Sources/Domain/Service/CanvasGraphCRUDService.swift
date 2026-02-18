// Background: Core graph editing must stay framework-agnostic and deterministic.
// Responsibility: Provide pure CRUD operations with invariant validation.
/// Pure domain service for immutable graph CRUD operations.
public enum CanvasGraphCRUDService {
    /// Inserts a node into the graph.
    /// - Parameters:
    ///   - node: Node to insert.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph containing the inserted node or a domain validation error.
    public static func createNode(_ node: CanvasNode, in graph: CanvasGraph) -> Result<CanvasGraph, CanvasGraphError> {
        switch validate(node: node) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        guard graph.nodesByID[node.id] == nil else {
            return .failure(.nodeAlreadyExists(node.id))
        }

        var nodes = graph.nodesByID
        nodes[node.id] = node
        return .success(
            CanvasGraph(
                nodesByID: nodes,
                edgesByID: graph.edgesByID,
                focusedNodeID: graph.focusedNodeID
            ))
    }

    /// Replaces an existing node.
    /// - Parameters:
    ///   - node: New node value.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph containing the updated node or a domain validation error.
    public static func updateNode(_ node: CanvasNode, in graph: CanvasGraph) -> Result<CanvasGraph, CanvasGraphError> {
        switch validate(node: node) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        guard graph.nodesByID[node.id] != nil else {
            return .failure(.nodeNotFound(node.id))
        }

        var nodes = graph.nodesByID
        nodes[node.id] = node
        return .success(
            CanvasGraph(
                nodesByID: nodes,
                edgesByID: graph.edgesByID,
                focusedNodeID: graph.focusedNodeID
            ))
    }

    /// Deletes a node and all connected edges.
    /// - Parameters:
    ///   - id: Node identifier to remove.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph without the node and related edges, or `.nodeNotFound`.
    public static func deleteNode(id: CanvasNodeID, in graph: CanvasGraph) -> Result<CanvasGraph, CanvasGraphError> {
        guard graph.nodesByID[id] != nil else {
            return .failure(.nodeNotFound(id))
        }

        var nodes = graph.nodesByID
        nodes.removeValue(forKey: id)
        let edges = graph.edgesByID.filter { _, edge in
            edge.fromNodeID != id && edge.toNodeID != id
        }

        let nextFocusedNodeID = graph.focusedNodeID == id ? nil : graph.focusedNodeID
        return .success(
            CanvasGraph(
                nodesByID: nodes,
                edgesByID: edges,
                focusedNodeID: nextFocusedNodeID
            ))
    }

    /// Inserts an edge into the graph.
    /// - Parameters:
    ///   - edge: Edge to insert.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph containing the inserted edge or a domain validation error.
    public static func createEdge(_ edge: CanvasEdge, in graph: CanvasGraph) -> Result<CanvasGraph, CanvasGraphError> {
        switch validate(edge: edge, in: graph) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        guard graph.edgesByID[edge.id] == nil else {
            return .failure(.edgeAlreadyExists(edge.id))
        }

        var edges = graph.edgesByID
        edges[edge.id] = edge
        return .success(
            CanvasGraph(
                nodesByID: graph.nodesByID,
                edgesByID: edges,
                focusedNodeID: graph.focusedNodeID
            ))
    }

    /// Deletes an edge.
    /// - Parameters:
    ///   - id: Edge identifier to remove.
    ///   - graph: Source graph snapshot.
    /// - Returns: New graph without the target edge, or `.edgeNotFound`.
    public static func deleteEdge(id: CanvasEdgeID, in graph: CanvasGraph) -> Result<CanvasGraph, CanvasGraphError> {
        guard graph.edgesByID[id] != nil else {
            return .failure(.edgeNotFound(id))
        }

        var edges = graph.edgesByID
        edges.removeValue(forKey: id)
        return .success(
            CanvasGraph(
                nodesByID: graph.nodesByID,
                edgesByID: edges,
                focusedNodeID: graph.focusedNodeID
            ))
    }
}

extension CanvasGraphCRUDService {
    /// Validates node invariants before insert/update.
    /// - Parameter node: Candidate node value.
    /// - Returns: `.success(())` when valid, otherwise the corresponding error.
    fileprivate static func validate(node: CanvasNode) -> Result<Void, CanvasGraphError> {
        if node.id.rawValue.isEmpty {
            return .failure(.invalidNodeID)
        }
        if node.bounds.width <= 0 || node.bounds.height <= 0 {
            return .failure(.invalidNodeBounds)
        }
        return .success(())
    }

    /// Validates edge invariants before insert/update.
    /// - Parameters:
    ///   - edge: Candidate edge value.
    ///   - graph: Graph snapshot used for endpoint existence checks.
    /// - Returns: `.success(())` when valid, otherwise the corresponding error.
    fileprivate static func validate(edge: CanvasEdge, in graph: CanvasGraph) -> Result<Void, CanvasGraphError> {
        if edge.id.rawValue.isEmpty {
            return .failure(.invalidEdgeID)
        }
        guard graph.nodesByID[edge.fromNodeID] != nil else {
            return .failure(.edgeEndpointNotFound(edge.fromNodeID))
        }
        guard graph.nodesByID[edge.toNodeID] != nil else {
            return .failure(.edgeEndpointNotFound(edge.toNodeID))
        }
        return .success(())
    }
}
