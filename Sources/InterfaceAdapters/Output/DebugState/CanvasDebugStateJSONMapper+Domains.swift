// Background: External debuggers need domain-oriented snapshots, not only full graph dumps.
// Responsibility: Build per-domain debug payloads (D1-D7) from a session apply result.
import Application
import Domain
import Foundation

extension CanvasDebugStateJSONMapper {
    /// Builds domain catalog payload for `/debug/v1/sessions/{id}/domains`.
    /// - Parameter sessionID: Target session identifier.
    /// - Returns: Encoded JSON payload.
    public static func makeDomainCatalogPayload(sessionID: CanvasSessionID) throws -> Data {
        let payload = DomainCatalogPayload(
            schemaVersion: "debug-state.v1",
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            sessionID: sessionID.rawValue,
            domainCount: CanvasDebugDomainID.allCases.count,
            domains: domainCatalogEntries(sessionID: sessionID)
        )
        return try JSONEncoder().encode(payload)
    }

    /// Builds domain-specific state payload for `/debug/v1/sessions/{id}/domains/{domainID}`.
    /// - Parameters:
    ///   - sessionID: Target session identifier.
    ///   - result: Latest apply result for the session.
    ///   - domainID: Target domain identifier.
    /// - Returns: Encoded JSON payload.
    public static func makeDomainStatePayload(
        sessionID: CanvasSessionID,
        result: ApplyResult,
        domainID: CanvasDebugDomainID
    ) throws -> Data {
        switch domainID {
        case .d1CanvasGraphEditing:
            return try makeD1Payload(sessionID: sessionID, graph: result.newState)
        case .d2FocusAndSelection:
            return try makeD2Payload(sessionID: sessionID, graph: result.newState)
        case .d3AreaLayout:
            return try makeD3Payload(sessionID: sessionID, graph: result.newState)
        case .d4TreeLayout:
            return try makeD4Payload(sessionID: sessionID, graph: result.newState)
        case .d5ShortcutCatalog:
            return try makeD5Payload(sessionID: sessionID)
        case .d6FoldVisibility:
            return try makeD6Payload(sessionID: sessionID, graph: result.newState)
        case .d7AreaModeMembership:
            return try makeD7Payload(sessionID: sessionID, graph: result.newState)
        }
    }
}

extension CanvasDebugStateJSONMapper {
    private static func makeDomainEnvelope<State: Codable>(
        sessionID: CanvasSessionID,
        domainID: CanvasDebugDomainID,
        state: State
    ) throws -> Data {
        let payload = DomainStateEnvelope(
            schemaVersion: "debug-state.v1",
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            sessionID: sessionID.rawValue,
            domainID: domainID.rawValue,
            domainName: domainID.displayName,
            state: state
        )
        return try JSONEncoder().encode(payload)
    }

    private static func domainCatalogEntries(sessionID: CanvasSessionID) -> [DomainCatalogEntryPayload] {
        CanvasDebugDomainID.allCases.map { domainID in
            DomainCatalogEntryPayload(
                domainID: domainID.rawValue,
                domainName: domainID.displayName,
                statePath: "/debug/v1/sessions/\(sessionID.rawValue)/domains/\(domainID.rawValue)"
            )
        }
    }

    private static func makeD1Payload(sessionID: CanvasSessionID, graph: CanvasGraph) throws -> Data {
        try makeDomainEnvelope(
            sessionID: sessionID,
            domainID: .d1CanvasGraphEditing,
            state: DomainCanvasGraphEditingState(
                nodeCount: graph.nodesByID.count,
                edgeCount: graph.edgesByID.count,
                graph: GraphPayload.make(from: graph)
            )
        )
    }

    private static func makeD2Payload(sessionID: CanvasSessionID, graph: CanvasGraph) throws -> Data {
        try makeDomainEnvelope(
            sessionID: sessionID,
            domainID: .d2FocusAndSelection,
            state: DomainFocusAndSelectionState(
                focusedNodeID: graph.focusedNodeID?.rawValue,
                focusedElement: FocusedElementPayload.make(from: graph.focusedElement),
                selectedNodeIDs: graph.selectedNodeIDs.map(\.rawValue).sorted(),
                selectedEdgeIDs: graph.selectedEdgeIDs.map(\.rawValue).sorted()
            )
        )
    }

    private static func makeD3Payload(sessionID: CanvasSessionID, graph: CanvasGraph) throws -> Data {
        let areas = graph.areasByID.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { area in
                DomainAreaLayoutItem(
                    areaID: area.id.rawValue,
                    editingMode: area.editingMode.debugStateRawValue,
                    nodeCount: area.nodeIDs.count,
                    bounds: areaBounds(for: area, in: graph)
                )
            }

        return try makeDomainEnvelope(
            sessionID: sessionID,
            domainID: .d3AreaLayout,
            state: DomainAreaLayoutState(areaCount: areas.count, areas: areas)
        )
    }

    private static func makeD4Payload(sessionID: CanvasSessionID, graph: CanvasGraph) throws -> Data {
        try makeDomainEnvelope(
            sessionID: sessionID,
            domainID: .d4TreeLayout,
            state: DomainTreeLayoutState(
                rootNodeIDs: treeRootNodeIDs(in: graph),
                parentChildEdges: treeParentChildEdges(in: graph)
            )
        )
    }

    private static func makeD5Payload(sessionID: CanvasSessionID) throws -> Data {
        try makeDomainEnvelope(
            sessionID: sessionID,
            domainID: .d5ShortcutCatalog,
            state: makeShortcutCatalogState()
        )
    }

    private static func makeD6Payload(sessionID: CanvasSessionID, graph: CanvasGraph) throws -> Data {
        try makeDomainEnvelope(
            sessionID: sessionID,
            domainID: .d6FoldVisibility,
            state: DomainFoldVisibilityState(
                collapsedRootNodeIDs: graph.collapsedRootNodeIDs.map(\.rawValue).sorted(),
                hiddenNodeIDs: CanvasFoldedSubtreeVisibilityService.hiddenNodeIDs(in: graph).map(\.rawValue).sorted(),
                visibleNodeIDs: CanvasFoldedSubtreeVisibilityService.visibleNodeIDs(in: graph).map(\.rawValue).sorted()
            )
        )
    }

    private static func makeD7Payload(sessionID: CanvasSessionID, graph: CanvasGraph) throws -> Data {
        let areas = graph.areasByID.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { area in
                DomainAreaModeMembershipItem(
                    areaID: area.id.rawValue,
                    editingMode: area.editingMode.debugStateRawValue,
                    nodeIDs: area.nodeIDs.map(\.rawValue).sorted()
                )
            }

        return try makeDomainEnvelope(
            sessionID: sessionID,
            domainID: .d7AreaModeMembership,
            state: DomainAreaModeMembershipState(
                areas: areas,
                orphanNodeIDs: orphanNodeIDs(in: graph)
            )
        )
    }
}

extension CanvasDebugStateJSONMapper {
    private static func areaBounds(for area: CanvasArea, in graph: CanvasGraph) -> BoundsPayload? {
        let nodes = area.nodeIDs.compactMap { graph.nodesByID[$0] }
        guard let firstNode = nodes.first else {
            return nil
        }

        var minX = firstNode.bounds.x
        var minY = firstNode.bounds.y
        var maxX = firstNode.bounds.x + firstNode.bounds.width
        var maxY = firstNode.bounds.y + firstNode.bounds.height

        for node in nodes.dropFirst() {
            minX = min(minX, node.bounds.x)
            minY = min(minY, node.bounds.y)
            maxX = max(maxX, node.bounds.x + node.bounds.width)
            maxY = max(maxY, node.bounds.y + node.bounds.height)
        }

        return BoundsPayload(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func treeParentChildEdges(in graph: CanvasGraph) -> [DomainTreeEdgeItem] {
        graph.edgesByID.values
            .filter { edge in
                edge.relationType == .parentChild
                    && graph.nodesByID[edge.fromNodeID] != nil
                    && graph.nodesByID[edge.toNodeID] != nil
            }
            .sorted { lhs, rhs in
                if lhs.fromNodeID.rawValue != rhs.fromNodeID.rawValue {
                    return lhs.fromNodeID.rawValue < rhs.fromNodeID.rawValue
                }
                if lhs.parentChildOrder != rhs.parentChildOrder {
                    return (lhs.parentChildOrder ?? Int.max) < (rhs.parentChildOrder ?? Int.max)
                }
                if lhs.toNodeID.rawValue != rhs.toNodeID.rawValue {
                    return lhs.toNodeID.rawValue < rhs.toNodeID.rawValue
                }
                return lhs.id.rawValue < rhs.id.rawValue
            }
            .map { edge in
                DomainTreeEdgeItem(
                    edgeID: edge.id.rawValue,
                    parentNodeID: edge.fromNodeID.rawValue,
                    childNodeID: edge.toNodeID.rawValue,
                    parentChildOrder: edge.parentChildOrder
                )
            }
    }

    private static func treeRootNodeIDs(in graph: CanvasGraph) -> [String] {
        let parentChildEdges = graph.edgesByID.values.filter { $0.relationType == .parentChild }
        let childNodeIDs = Set(parentChildEdges.map(\.toNodeID))

        return graph.nodesByID.keys
            .filter { !childNodeIDs.contains($0) }
            .map(\.rawValue)
            .sorted()
    }

    private static func orphanNodeIDs(in graph: CanvasGraph) -> [String] {
        let assignedNodeIDs = Set(graph.areasByID.values.flatMap(\.nodeIDs))
        return Set(graph.nodesByID.keys)
            .subtracting(assignedNodeIDs)
            .map(\.rawValue)
            .sorted()
    }

    private static func makeShortcutCatalogState() -> DomainShortcutCatalogState {
        let definitions = CanvasShortcutCatalogService.commandPaletteDefinitions()
            .sorted { $0.id.rawValue < $1.id.rawValue }

        let treeFocusedCount = commandPaletteItemCount(
            context: CanvasCommandPaletteContext(activeEditingMode: .tree, hasFocusedNode: true)
        )
        let diagramFocusedCount = commandPaletteItemCount(
            context: CanvasCommandPaletteContext(activeEditingMode: .diagram, hasFocusedNode: true)
        )
        let noFocusCount = commandPaletteItemCount(
            context: CanvasCommandPaletteContext(activeEditingMode: nil, hasFocusedNode: false)
        )

        let items = definitions.map { definition in
            DomainShortcutCatalogItem(
                id: definition.id.rawValue,
                title: definition.title,
                shortcutLabel: definition.shortcutLabel,
                actionKind: shortcutActionKind(for: definition.action),
                commandCount: shortcutCommandCount(for: definition.action)
            )
        }

        return DomainShortcutCatalogState(
            commandPaletteItemCount: items.count,
            visibleCountByContext: DomainShortcutContextCount(
                treeFocused: treeFocusedCount,
                diagramFocused: diagramFocusedCount,
                noFocus: noFocusCount
            ),
            items: items
        )
    }

    private static func commandPaletteItemCount(context: CanvasCommandPaletteContext) -> Int {
        CanvasShortcutCatalogService.commandPaletteDefinitions(context: context).count
    }

    private static func shortcutActionKind(for action: CanvasShortcutAction) -> String {
        switch action {
        case .apply:
            return "apply"
        case .undo:
            return "undo"
        case .redo:
            return "redo"
        case .zoomIn:
            return "zoom-in"
        case .zoomOut:
            return "zoom-out"
        case .beginConnectNodeSelection:
            return "begin-connect-node-selection"
        case .openCommandPalette:
            return "open-command-palette"
        }
    }

    private static func shortcutCommandCount(for action: CanvasShortcutAction) -> Int? {
        guard case .apply(let commands) = action else {
            return nil
        }
        return commands.count
    }
}

extension CanvasDebugStateJSONMapper {
    private struct DomainCatalogPayload: Codable {
        let schemaVersion: String
        let generatedAt: String
        let sessionID: String
        let domainCount: Int
        let domains: [DomainCatalogEntryPayload]
    }

    private struct DomainCatalogEntryPayload: Codable {
        let domainID: String
        let domainName: String
        let statePath: String
    }

    private struct DomainStateEnvelope<State: Codable>: Codable {
        let schemaVersion: String
        let generatedAt: String
        let sessionID: String
        let domainID: String
        let domainName: String
        let state: State
    }

    private struct DomainCanvasGraphEditingState: Codable {
        let nodeCount: Int
        let edgeCount: Int
        let graph: GraphPayload
    }

    private struct DomainFocusAndSelectionState: Codable {
        let focusedNodeID: String?
        let focusedElement: FocusedElementPayload?
        let selectedNodeIDs: [String]
        let selectedEdgeIDs: [String]
    }

    private struct DomainAreaLayoutState: Codable {
        let areaCount: Int
        let areas: [DomainAreaLayoutItem]
    }

    private struct DomainAreaLayoutItem: Codable {
        let areaID: String
        let editingMode: String
        let nodeCount: Int
        let bounds: BoundsPayload?
    }

    private struct DomainTreeLayoutState: Codable {
        let rootNodeIDs: [String]
        let parentChildEdges: [DomainTreeEdgeItem]
    }

    private struct DomainTreeEdgeItem: Codable {
        let edgeID: String
        let parentNodeID: String
        let childNodeID: String
        let parentChildOrder: Int?
    }

    private struct DomainShortcutCatalogState: Codable {
        let commandPaletteItemCount: Int
        let visibleCountByContext: DomainShortcutContextCount
        let items: [DomainShortcutCatalogItem]
    }

    private struct DomainShortcutContextCount: Codable {
        let treeFocused: Int
        let diagramFocused: Int
        let noFocus: Int
    }

    private struct DomainShortcutCatalogItem: Codable {
        let id: String
        let title: String
        let shortcutLabel: String
        let actionKind: String
        let commandCount: Int?
    }

    private struct DomainFoldVisibilityState: Codable {
        let collapsedRootNodeIDs: [String]
        let hiddenNodeIDs: [String]
        let visibleNodeIDs: [String]
    }

    private struct DomainAreaModeMembershipState: Codable {
        let areas: [DomainAreaModeMembershipItem]
        let orphanNodeIDs: [String]
    }

    private struct DomainAreaModeMembershipItem: Codable {
        let areaID: String
        let editingMode: String
        let nodeIDs: [String]
    }
}
