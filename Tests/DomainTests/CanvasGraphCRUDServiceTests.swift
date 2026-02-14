import Domain
import Testing

@Test("Node CRUD: text node can be created, updated, and deleted")
func test_nodeCrud_textNode_lifecycleWorks() throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let initialNode = CanvasNode(
        id: nodeID,
        kind: .text,
        text: "first",
        bounds: CanvasBounds(x: 0, y: 0, width: 240, height: 120)
    )

    let createdGraph = try CanvasGraphCRUDService.createNode(initialNode, in: .empty)
    #expect(CanvasGraphCRUDService.readNode(id: nodeID, in: createdGraph)?.text == "first")

    let updatedNode = CanvasNode(
        id: nodeID,
        kind: .text,
        text: "updated",
        bounds: CanvasBounds(x: 10, y: 20, width: 300, height: 160),
        metadata: ["purpose": "memo"]
    )
    let updatedGraph = try CanvasGraphCRUDService.updateNode(updatedNode, in: createdGraph)
    #expect(CanvasGraphCRUDService.readNode(id: nodeID, in: updatedGraph)?.text == "updated")
    #expect(CanvasGraphCRUDService.readNode(id: nodeID, in: updatedGraph)?.metadata["purpose"] == "memo")

    let deletedGraph = try CanvasGraphCRUDService.deleteNode(id: nodeID, in: updatedGraph)
    #expect(CanvasGraphCRUDService.readNode(id: nodeID, in: deletedGraph) == nil)
}

@Test("Edge CRUD: edge requires existing node endpoints")
func test_edgeCrud_withExistingNodes_lifecycleWorks() throws {
    let fromNode = CanvasNode(
        id: CanvasNodeID(rawValue: "from"),
        kind: .text,
        text: "from",
        bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 60)
    )
    let toNode = CanvasNode(
        id: CanvasNodeID(rawValue: "to"),
        kind: .text,
        text: "to",
        bounds: CanvasBounds(x: 120, y: 40, width: 100, height: 60)
    )

    var graph = try CanvasGraphCRUDService.createNode(fromNode, in: .empty)
    graph = try CanvasGraphCRUDService.createNode(toNode, in: graph)

    let edgeID = CanvasEdgeID(rawValue: "edge-1")
    let edge = CanvasEdge(id: edgeID, fromNodeID: fromNode.id, toNodeID: toNode.id, label: "flow")
    graph = try CanvasGraphCRUDService.createEdge(edge, in: graph)
    #expect(CanvasGraphCRUDService.readEdge(id: edgeID, in: graph)?.label == "flow")

    let updatedEdge = CanvasEdge(id: edgeID, fromNodeID: fromNode.id, toNodeID: toNode.id, label: "updated")
    graph = try CanvasGraphCRUDService.updateEdge(updatedEdge, in: graph)
    #expect(CanvasGraphCRUDService.readEdge(id: edgeID, in: graph)?.label == "updated")

    graph = try CanvasGraphCRUDService.deleteEdge(id: edgeID, in: graph)
    #expect(CanvasGraphCRUDService.readEdge(id: edgeID, in: graph) == nil)
}

@Test("Deleting a node also removes related edges")
func test_deleteNode_removesConnectedEdges() throws {
    let fromNode = CanvasNode(
        id: CanvasNodeID(rawValue: "from"),
        kind: .text,
        text: "from",
        bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 60)
    )
    let toNode = CanvasNode(
        id: CanvasNodeID(rawValue: "to"),
        kind: .text,
        text: "to",
        bounds: CanvasBounds(x: 120, y: 0, width: 100, height: 60)
    )
    let edgeID = CanvasEdgeID(rawValue: "edge-1")

    var graph = try CanvasGraphCRUDService.createNode(fromNode, in: .empty)
    graph = try CanvasGraphCRUDService.createNode(toNode, in: graph)
    graph = try CanvasGraphCRUDService.createEdge(
        CanvasEdge(id: edgeID, fromNodeID: fromNode.id, toNodeID: toNode.id),
        in: graph
    )

    let prunedGraph = try CanvasGraphCRUDService.deleteNode(id: fromNode.id, in: graph)
    #expect(CanvasGraphCRUDService.readNode(id: fromNode.id, in: prunedGraph) == nil)
    #expect(CanvasGraphCRUDService.readEdge(id: edgeID, in: prunedGraph) == nil)
}

@Test("Validation: creating invalid edge or duplicate node fails")
func test_validation_invalidOperations_throwExpectedErrors() throws {
    let node = CanvasNode(
        id: CanvasNodeID(rawValue: "node-1"),
        kind: .text,
        text: "text",
        bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 80)
    )
    let graph = try CanvasGraphCRUDService.createNode(node, in: .empty)

    do {
        _ = try CanvasGraphCRUDService.createNode(node, in: graph)
        Issue.record("expected duplicate node error")
    } catch let error as CanvasGraphError {
        #expect(error == .nodeAlreadyExists(node.id))
    }

    let missingNodeID = CanvasNodeID(rawValue: "missing")
    do {
        _ = try CanvasGraphCRUDService.createEdge(
            CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-1"),
                fromNodeID: node.id,
                toNodeID: missingNodeID
            ),
            in: graph
        )
        Issue.record("expected missing endpoint error")
    } catch let error as CanvasGraphError {
        #expect(error == .edgeEndpointNotFound(missingNodeID))
    }
}
