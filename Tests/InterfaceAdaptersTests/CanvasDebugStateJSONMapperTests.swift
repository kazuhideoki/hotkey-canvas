// Background: External automation relies on stable JSON schema for canvas debug snapshots.
// Responsibility: Verify JSON mapper emits expected shape and key values.
import Application
import Domain
import Foundation
import InterfaceAdapters
import Testing

@Test("CanvasDebugStateJSONMapper: sessions payload includes summary rows")
func test_sessionsPayload_includesSummaryRows() throws {
    let firstID = CanvasSessionID(rawValue: "session-a")
    let secondID = CanvasSessionID(rawValue: "session-b")

    let firstGraph = CanvasGraph.empty
    let secondNodeID = CanvasNodeID(rawValue: "node-1")
    let secondGraph = CanvasGraph(
        nodesByID: [
            secondNodeID: CanvasNode(
                id: secondNodeID,
                kind: .text,
                text: "hello",
                bounds: CanvasBounds(x: 10, y: 20, width: 220, height: 41)
            )
        ],
        focusedNodeID: secondNodeID,
        selectedNodeIDs: [secondNodeID],
        areasByID: [
            .defaultTree: CanvasArea(id: .defaultTree, nodeIDs: [secondNodeID], editingMode: .tree)
        ]
    )

    let sessions = [
        firstID: ApplyResult(newState: firstGraph),
        secondID: ApplyResult(newState: secondGraph),
    ]

    let data = try CanvasDebugStateJSONMapper.makeSessionsPayload(resultsBySessionID: sessions)
    let root = try jsonObject(from: data)

    #expect(root["schemaVersion"] as? String == "debug-state.v1")
    let rows = root["sessions"] as? [[String: Any]]
    #expect(rows?.count == 2)
    #expect(rows?.first?["sessionID"] as? String == "session-a")
    #expect(rows?.last?["sessionID"] as? String == "session-b")
    #expect(rows?.last?["nodeCount"] as? Int == 1)
    #expect(rows?.last?["focusedNodeID"] as? String == "node-1")
}

@Test("CanvasDebugStateJSONMapper: session state payload includes graph and ui fields")
func test_sessionStatePayload_includesGraphAndUI() throws {
    let sessionID = CanvasSessionID(rawValue: "session-a")
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let edgeID = CanvasEdgeID(rawValue: "edge-1")
    let areaID = CanvasAreaID(rawValue: "area-1")

    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "hello",
                attachments: [
                    CanvasAttachment(
                        id: CanvasAttachmentID(rawValue: "attachment-1"),
                        kind: .image(filePath: "/tmp/image.png"),
                        placement: .aboveText
                    )
                ],
                bounds: CanvasBounds(x: 10, y: 20, width: 220, height: 220),
                markdownStyleEnabled: false
            )
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: nodeID,
                toNodeID: nodeID,
                relationType: .normal,
                parentChildOrder: 3,
                label: "loop"
            )
        ],
        focusedNodeID: nodeID,
        selectedNodeIDs: [nodeID],
        selectedEdgeIDs: [edgeID],
        collapsedRootNodeIDs: [nodeID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let result = ApplyResult(newState: graph, canUndo: true, canRedo: false)

    let data = try CanvasDebugStateJSONMapper.makeSessionStatePayload(
        sessionID: sessionID,
        result: result
    )
    let root = try jsonObject(from: data)

    #expect(root["sessionID"] as? String == "session-a")
    let ui = root["ui"] as? [String: Any]
    #expect(ui?["canUndo"] as? Bool == true)
    #expect(ui?["canRedo"] as? Bool == false)

    let graphObject = root["graph"] as? [String: Any]
    let nodes = graphObject?["nodes"] as? [[String: Any]]
    #expect(nodes?.count == 1)
    #expect(nodes?.first?["id"] as? String == "node-1")

    let edges = graphObject?["edges"] as? [[String: Any]]
    #expect(edges?.count == 1)
    #expect(edges?.first?["id"] as? String == "edge-1")
    #expect(edges?.first?["directionality"] as? String == "none")

    let areaRows = graphObject?["areas"] as? [[String: Any]]
    #expect(areaRows?.first?["editingMode"] as? String == "diagram")
}

@Test("CanvasDebugStateJSONMapper: domain catalog payload includes all domain endpoints")
func test_domainCatalogPayload_includesAllDomainEndpoints() throws {
    let sessionID = CanvasSessionID(rawValue: "session-a")
    let data = try CanvasDebugStateJSONMapper.makeDomainCatalogPayload(sessionID: sessionID)
    let root = try jsonObject(from: data)

    #expect(root["schemaVersion"] as? String == "debug-state.v1")
    #expect(root["sessionID"] as? String == "session-a")
    #expect(root["domainCount"] as? Int == 7)

    let domains = root["domains"] as? [[String: Any]]
    #expect(domains?.count == 7)
    #expect(domains?.first?["domainID"] as? String == "d1-canvas-graph-editing")
    #expect(
        domains?.first?["statePath"] as? String == "/debug/v1/sessions/session-a/domains/d1-canvas-graph-editing"
    )
}

@Test("CanvasDebugStateJSONMapper: fold visibility domain payload includes hidden and visible nodes")
func test_domainStatePayload_foldVisibility_includesHiddenAndVisibleNodes() throws {
    let sessionID = CanvasSessionID(rawValue: "session-a")
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeID = CanvasEdgeID(rawValue: "edge-1")

    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID, kind: .text, text: "root", bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 40)),
            childID: CanvasNode(
                id: childID, kind: .text, text: "child", bounds: CanvasBounds(x: 200, y: 0, width: 120, height: 40)),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        collapsedRootNodeIDs: [rootID],
        areasByID: [
            .defaultTree: CanvasArea(id: .defaultTree, nodeIDs: [rootID, childID], editingMode: .tree)
        ]
    )
    let result = ApplyResult(newState: graph)
    let data = try CanvasDebugStateJSONMapper.makeDomainStatePayload(
        sessionID: sessionID,
        result: result,
        domainID: .d6FoldVisibility
    )
    let root = try jsonObject(from: data)

    #expect(root["domainID"] as? String == "d6-fold-visibility")
    let state = root["state"] as? [String: Any]
    #expect(state?["collapsedRootNodeIDs"] as? [String] == ["root"])
    #expect(state?["hiddenNodeIDs"] as? [String] == ["child"])
    #expect(state?["visibleNodeIDs"] as? [String] == ["root"])
}

private func jsonObject(from data: Data) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: data)
    guard let dictionary = object as? [String: Any] else {
        throw NSError(domain: "CanvasDebugStateJSONMapperTests", code: 1)
    }
    return dictionary
}
