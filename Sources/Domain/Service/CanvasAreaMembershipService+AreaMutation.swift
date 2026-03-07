// Background: Focused area operations mutate area mode and rendering style while preserving membership validity.
// Responsibility: Apply focused-area mutations and shared cross-area edge validation helpers.
extension CanvasAreaMembershipService {
    /// Converts the focused node area editing mode.
    /// - Parameters:
    ///   - mode: Target editing mode.
    ///   - graph: Source graph.
    /// - Returns: Graph with converted focused area mode.
    public static func convertFocusedAreaMode(
        to mode: CanvasEditingMode,
        in graph: CanvasGraph
    ) -> Result<CanvasGraph, CanvasAreaPolicyError> {
        switch focusedAreaID(in: graph) {
        case .success(let areaID):
            guard let focusedArea = graph.areasByID[areaID] else {
                return .failure(.areaNotFound(areaID))
            }
            if focusedArea.editingMode == mode {
                return .success(graph)
            }

            var nextAreasByID = graph.areasByID
            nextAreasByID[areaID] = CanvasArea(
                id: focusedArea.id,
                nodeIDs: focusedArea.nodeIDs,
                editingMode: mode,
                edgeShapeStyle: focusedArea.edgeShapeStyle
            )
            let nextGraph = CanvasGraph(
                nodesByID: graph.nodesByID,
                edgesByID: graph.edgesByID,
                focusedNodeID: graph.focusedNodeID,
                selectedNodeIDs: graph.selectedNodeIDs,
                collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
                areasByID: nextAreasByID
            )
            switch validate(in: nextGraph) {
            case .success:
                return .success(nextGraph)
            case .failure(let error):
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Toggles focused area edge shape style.
    /// - Parameter graph: Source graph.
    /// - Returns: Graph with toggled edge shape style in focused area.
    public static func toggleFocusedAreaEdgeShapeStyle(
        in graph: CanvasGraph
    ) -> Result<CanvasGraph, CanvasAreaPolicyError> {
        switch focusedAreaID(in: graph) {
        case .success(let areaID):
            guard let focusedArea = graph.areasByID[areaID] else {
                return .failure(.areaNotFound(areaID))
            }
            var nextAreasByID = graph.areasByID
            nextAreasByID[areaID] = CanvasArea(
                id: focusedArea.id,
                nodeIDs: focusedArea.nodeIDs,
                editingMode: focusedArea.editingMode,
                edgeShapeStyle: focusedArea.edgeShapeStyle.toggled
            )
            let nextGraph = CanvasGraph(
                nodesByID: graph.nodesByID,
                edgesByID: graph.edgesByID,
                focusedNodeID: graph.focusedNodeID,
                focusedElement: graph.focusedElement,
                selectedNodeIDs: graph.selectedNodeIDs,
                selectedEdgeIDs: graph.selectedEdgeIDs,
                collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
                areasByID: nextAreasByID
            )
            switch validate(in: nextGraph) {
            case .success:
                return .success(nextGraph)
            case .failure(let error):
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Validates that every edge stays within one area.
    /// - Parameter graph: Graph snapshot.
    /// - Returns: `.success(())` when all edges are intra-area.
    static func validateNoCrossAreaEdges(in graph: CanvasGraph) -> Result<Void, CanvasAreaPolicyError> {
        for edgeID in graph.edgesByID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let edge = graph.edgesByID[edgeID] else {
                continue
            }
            switch areaID(containing: edge.fromNodeID, in: graph) {
            case .success(let fromAreaID):
                switch areaID(containing: edge.toNodeID, in: graph) {
                case .success(let toAreaID):
                    if fromAreaID != toAreaID && isCrossAreaEdgeAllowed(from: fromAreaID, to: toAreaID) == false {
                        return .failure(.crossAreaEdgeForbidden(edge.id))
                    }
                case .failure(let error):
                    return .failure(error)
                }
            case .failure(let error):
                return .failure(error)
            }
        }
        return .success(())
    }

    /// Hook for future policy expansion where cross-area edges may become allowed.
    static func isCrossAreaEdgeAllowed(from _: CanvasAreaID, to _: CanvasAreaID) -> Bool {
        false
    }
}
