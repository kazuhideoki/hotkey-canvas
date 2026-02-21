// Background: Domain graph edits are pure and should be regression-tested by invariants.
// Responsibility: Verify CRUD behavior and validation rules of CanvasGraphCRUDService.
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

    let createdGraph = try CanvasGraphCRUDService.createNode(initialNode, in: .empty).get()
    #expect(createdGraph.nodesByID[nodeID]?.text == "first")

    let updatedNode = CanvasNode(
        id: nodeID,
        kind: .text,
        text: "updated",
        bounds: CanvasBounds(x: 10, y: 20, width: 300, height: 160),
        metadata: ["purpose": "memo"]
    )
    let updatedGraph = try CanvasGraphCRUDService.updateNode(updatedNode, in: createdGraph).get()
    #expect(updatedGraph.nodesByID[nodeID]?.text == "updated")
    #expect(updatedGraph.nodesByID[nodeID]?.metadata["purpose"] == "memo")

    let deletedGraph = try CanvasGraphCRUDService.deleteNode(id: nodeID, in: updatedGraph).get()
    #expect(deletedGraph.nodesByID[nodeID] == nil)
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

    var graph = try CanvasGraphCRUDService.createNode(fromNode, in: .empty).get()
    graph = try CanvasGraphCRUDService.createNode(toNode, in: graph).get()

    let edgeID = CanvasEdgeID(rawValue: "edge-1")
    let edge = CanvasEdge(
        id: edgeID,
        fromNodeID: fromNode.id,
        toNodeID: toNode.id,
        relationType: .parentChild,
        label: "flow"
    )
    graph = try CanvasGraphCRUDService.createEdge(edge, in: graph).get()
    #expect(graph.edgesByID[edgeID]?.label == "flow")
    #expect(graph.edgesByID[edgeID]?.relationType == .parentChild)

    graph = try CanvasGraphCRUDService.deleteEdge(id: edgeID, in: graph).get()
    #expect(graph.edgesByID[edgeID] == nil)
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

    var graph = try CanvasGraphCRUDService.createNode(fromNode, in: .empty).get()
    graph = try CanvasGraphCRUDService.createNode(toNode, in: graph).get()
    graph = try CanvasGraphCRUDService.createEdge(
        CanvasEdge(id: edgeID, fromNodeID: fromNode.id, toNodeID: toNode.id),
        in: graph
    ).get()

    let prunedGraph = try CanvasGraphCRUDService.deleteNode(id: fromNode.id, in: graph).get()
    #expect(prunedGraph.nodesByID[fromNode.id] == nil)
    #expect(prunedGraph.edgesByID[edgeID] == nil)
}

@Test("Deleting focused node clears focus")
func test_deleteNode_clearsFocus_whenDeletingFocusedNode() throws {
    let focusedNode = CanvasNode(
        id: CanvasNodeID(rawValue: "focused"),
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 60)
    )
    let graph = CanvasGraph(
        nodesByID: [focusedNode.id: focusedNode],
        edgesByID: [:],
        focusedNodeID: focusedNode.id
    )

    let prunedGraph = try CanvasGraphCRUDService.deleteNode(id: focusedNode.id, in: graph).get()

    #expect(prunedGraph.focusedNodeID == nil)
}

@Test("Graph CRUD preserves collapsed root state")
func test_crud_preservesCollapsedRootState() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let parentNode = CanvasNode(
        id: parentID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 60)
    )
    let childNode = CanvasNode(
        id: childID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 140, y: 0, width: 100, height: 60)
    )
    var graph = try CanvasGraphCRUDService.createNode(parentNode, in: .empty).get()
    graph = try CanvasGraphCRUDService.createNode(childNode, in: graph).get()
    graph = CanvasGraph(
        nodesByID: graph.nodesByID,
        edgesByID: graph.edgesByID,
        focusedNodeID: parentID,
        collapsedRootNodeIDs: [parentID]
    )

    let updatedChildNode = CanvasNode(
        id: childID,
        kind: .text,
        text: "updated",
        bounds: childNode.bounds
    )
    let updatedGraph = try CanvasGraphCRUDService.updateNode(updatedChildNode, in: graph).get()

    #expect(updatedGraph.collapsedRootNodeIDs == [parentID])
}

@Test("Validation: creating invalid edge or duplicate node fails")
func test_validation_invalidOperations_throwExpectedErrors() throws {
    let node = CanvasNode(
        id: CanvasNodeID(rawValue: "node-1"),
        kind: .text,
        text: "text",
        bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 80)
    )
    let graph = try CanvasGraphCRUDService.createNode(node, in: .empty).get()

    do {
        _ = try CanvasGraphCRUDService.createNode(node, in: graph).get()
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
        ).get()
        Issue.record("expected missing endpoint error")
    } catch let error as CanvasGraphError {
        #expect(error == .edgeEndpointNotFound(missingNodeID))
    }
}

@Test("Edge default relation type is normal")
func test_edge_defaultRelationType_isNormal() {
    let edge = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-default"),
        fromNodeID: CanvasNodeID(rawValue: "from"),
        toNodeID: CanvasNodeID(rawValue: "to")
    )
    #expect(edge.relationType == .normal)
}

@Test("Node CRUD: createNode assigns node into exactly one area")
func test_createNode_assignsNodeIntoSingleArea() throws {
    let existingNodeID = CanvasNodeID(rawValue: "existing")
    let newNodeID = CanvasNodeID(rawValue: "new")
    let areaID = CanvasAreaID(rawValue: "area-1")
    let existingNode = CanvasNode(
        id: existingNodeID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 80)
    )
    let newNode = CanvasNode(
        id: newNodeID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 200, y: 0, width: 120, height: 80)
    )
    let graph = CanvasGraph(
        nodesByID: [existingNodeID: existingNode],
        edgesByID: [:],
        focusedNodeID: existingNodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [existingNodeID], editingMode: .tree)
        ]
    )

    let createdGraph = try CanvasGraphCRUDService.createNode(newNode, in: graph).get()

    #expect(createdGraph.areasByID[areaID]?.nodeIDs.contains(newNodeID) == true)
    try CanvasAreaMembershipService.validate(in: createdGraph).get()
}

@Test("Node CRUD: deleteNode removes deleted node from all area memberships")
func test_deleteNode_removesDeletedNodeFromAreaMemberships() throws {
    let nodeID = CanvasNodeID(rawValue: "delete-me")
    let areaID = CanvasAreaID(rawValue: "area-1")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree)
        ]
    )

    let deletedGraph = try CanvasGraphCRUDService.deleteNode(id: nodeID, in: graph).get()

    #expect(deletedGraph.areasByID[areaID]?.nodeIDs.contains(nodeID) == false)
}
