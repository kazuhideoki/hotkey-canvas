// Background: Coding agents need deterministic external snapshots of in-memory canvas state during local development.
// Responsibility: Convert application session results into stable JSON payloads for debug state APIs.
import Application
import Domain
import Foundation

/// Maps session-level in-memory state into versioned debug JSON payloads.
public enum CanvasDebugStateJSONMapper {
    /// Builds session summary payload for `/debug/v1/sessions`.
    /// - Parameter resultsBySessionID: Latest apply results keyed by session identifier.
    /// - Returns: Encoded JSON payload.
    public static func makeSessionsPayload(resultsBySessionID: [CanvasSessionID: ApplyResult]) throws -> Data {
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        let sortedSessionIDs = resultsBySessionID.keys.sorted { $0.rawValue < $1.rawValue }
        let sessions = sortedSessionIDs.map { sessionID -> SessionSummaryPayload in
            guard let result = resultsBySessionID[sessionID] else {
                preconditionFailure("Session ID listed in keys must exist in dictionary: \(sessionID.rawValue)")
            }
            return SessionSummaryPayload(
                sessionID: sessionID.rawValue,
                nodeCount: result.newState.nodesByID.count,
                edgeCount: result.newState.edgesByID.count,
                focusedNodeID: result.newState.focusedNodeID?.rawValue,
                focusedEdgeID: focusedEdgeID(in: result.newState)
            )
        }

        let payload = SessionsPayload(
            schemaVersion: "debug-state.v1",
            generatedAt: generatedAt,
            sessionCount: sessions.count,
            sessions: sessions
        )
        return try JSONEncoder().encode(payload)
    }

    /// Builds full state payload for `/debug/v1/sessions/{id}/state`.
    /// - Parameters:
    ///   - sessionID: Target session identifier.
    ///   - result: Latest apply result.
    /// - Returns: Encoded JSON payload.
    public static func makeSessionStatePayload(sessionID: CanvasSessionID, result: ApplyResult) throws -> Data {
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        let payload = SessionStatePayload(
            schemaVersion: "debug-state.v1",
            generatedAt: generatedAt,
            sessionID: sessionID.rawValue,
            ui: UIPayload(canUndo: result.canUndo, canRedo: result.canRedo),
            graph: GraphPayload.make(from: result.newState)
        )
        return try JSONEncoder().encode(payload)
    }

    /// Builds health payload for `/debug/v1/health`.
    /// - Returns: Encoded JSON payload.
    public static func makeHealthPayload() throws -> Data {
        let payload = HealthPayload(
            schemaVersion: "debug-state.v1",
            status: "ok",
            generatedAt: ISO8601DateFormatter().string(from: Date())
        )
        return try JSONEncoder().encode(payload)
    }
}

extension CanvasDebugStateJSONMapper {
    static func focusedEdgeID(in graph: CanvasGraph) -> String? {
        guard case .edge(let edgeFocus) = graph.focusedElement else {
            return nil
        }
        return edgeFocus.edgeID.rawValue
    }
}

extension CanvasDebugStateJSONMapper {
    struct HealthPayload: Codable {
        let schemaVersion: String
        let status: String
        let generatedAt: String
    }

    struct SessionsPayload: Codable {
        let schemaVersion: String
        let generatedAt: String
        let sessionCount: Int
        let sessions: [SessionSummaryPayload]
    }

    struct SessionSummaryPayload: Codable {
        let sessionID: String
        let nodeCount: Int
        let edgeCount: Int
        let focusedNodeID: String?
        let focusedEdgeID: String?
    }

    struct SessionStatePayload: Codable {
        let schemaVersion: String
        let generatedAt: String
        let sessionID: String
        let ui: UIPayload
        let graph: GraphPayload
    }

    struct UIPayload: Codable {
        let canUndo: Bool
        let canRedo: Bool
    }

    struct GraphPayload: Codable {
        let focusedNodeID: String?
        let focusedElement: FocusedElementPayload?
        let selectedNodeIDs: [String]
        let selectedEdgeIDs: [String]
        let collapsedRootNodeIDs: [String]
        let nodes: [NodePayload]
        let edges: [EdgePayload]
        let areas: [AreaPayload]

        static func make(from graph: CanvasGraph) -> GraphPayload {
            GraphPayload(
                focusedNodeID: graph.focusedNodeID?.rawValue,
                focusedElement: FocusedElementPayload.make(from: graph.focusedElement),
                selectedNodeIDs: graph.selectedNodeIDs.map(\.rawValue).sorted(),
                selectedEdgeIDs: graph.selectedEdgeIDs.map(\.rawValue).sorted(),
                collapsedRootNodeIDs: graph.collapsedRootNodeIDs.map(\.rawValue).sorted(),
                nodes: graph.nodesByID.values
                    .sorted { $0.id.rawValue < $1.id.rawValue }
                    .map(NodePayload.make(from:)),
                edges: graph.edgesByID.values
                    .sorted { $0.id.rawValue < $1.id.rawValue }
                    .map(EdgePayload.make(from:)),
                areas: graph.areasByID.values
                    .sorted { $0.id.rawValue < $1.id.rawValue }
                    .map(AreaPayload.make(from:))
            )
        }
    }

    struct FocusedElementPayload: Codable {
        let kind: String
        let nodeID: String?
        let edgeID: String?
        let edgeOriginNodeID: String?

        static func make(from focusedElement: CanvasFocusedElement?) -> FocusedElementPayload? {
            guard let focusedElement else {
                return nil
            }
            switch focusedElement {
            case .node(let nodeID):
                return FocusedElementPayload(
                    kind: "node",
                    nodeID: nodeID.rawValue,
                    edgeID: nil,
                    edgeOriginNodeID: nil
                )
            case .edge(let edgeFocus):
                return FocusedElementPayload(
                    kind: "edge",
                    nodeID: nil,
                    edgeID: edgeFocus.edgeID.rawValue,
                    edgeOriginNodeID: edgeFocus.originNodeID.rawValue
                )
            }
        }
    }

    struct NodePayload: Codable {
        let id: String
        let kind: String
        let text: String?
        let bounds: BoundsPayload
        let attachments: [AttachmentPayload]
        let metadata: [String: String]
        let markdownStyleEnabled: Bool

        static func make(from node: CanvasNode) -> NodePayload {
            NodePayload(
                id: node.id.rawValue,
                kind: node.kind.rawValue,
                text: node.text,
                bounds: BoundsPayload.make(from: node.bounds),
                attachments: node.attachments
                    .sorted { $0.id.rawValue < $1.id.rawValue }
                    .map(AttachmentPayload.make(from:)),
                metadata: node.metadata,
                markdownStyleEnabled: node.markdownStyleEnabled
            )
        }
    }

    struct BoundsPayload: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        static func make(from bounds: CanvasBounds) -> BoundsPayload {
            BoundsPayload(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
        }
    }

    struct AttachmentPayload: Codable {
        let id: String
        let kind: String
        let filePath: String
        let placement: String

        static func make(from attachment: CanvasAttachment) -> AttachmentPayload {
            switch attachment.kind {
            case .image(let filePath):
                return AttachmentPayload(
                    id: attachment.id.rawValue,
                    kind: "image",
                    filePath: filePath,
                    placement: attachment.placement.debugStateRawValue
                )
            }
        }
    }

    struct EdgePayload: Codable {
        let id: String
        let fromNodeID: String
        let toNodeID: String
        let relationType: String
        let directionality: String
        let parentChildOrder: Int?
        let label: String?
        let metadata: [String: String]

        static func make(from edge: CanvasEdge) -> EdgePayload {
            EdgePayload(
                id: edge.id.rawValue,
                fromNodeID: edge.fromNodeID.rawValue,
                toNodeID: edge.toNodeID.rawValue,
                relationType: edge.relationType.rawValue,
                directionality: edge.directionality.rawValue,
                parentChildOrder: edge.parentChildOrder,
                label: edge.label,
                metadata: edge.metadata
            )
        }
    }

    struct AreaPayload: Codable {
        let id: String
        let editingMode: String
        let nodeIDs: [String]

        static func make(from area: CanvasArea) -> AreaPayload {
            AreaPayload(
                id: area.id.rawValue,
                editingMode: area.editingMode.debugStateRawValue,
                nodeIDs: area.nodeIDs.map(\.rawValue).sorted()
            )
        }
    }
}

extension CanvasAttachmentPlacement {
    var debugStateRawValue: String {
        switch self {
        case .aboveText:
            return "above-text"
        }
    }
}

extension CanvasEditingMode {
    var debugStateRawValue: String {
        switch self {
        case .tree:
            return "tree"
        case .diagram:
            return "diagram"
        }
    }
}
