// Background: Domain graph edits are pure and should be regression-tested by invariants.
// Responsibility: Verify CRUD behavior and validation rules of CanvasGraphCRUDService.
import Domain
import Testing

@Test("テキストノードの作成、更新、削除が可能")
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

@Test("エッジには既存のノード端点が必要である")
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

@Test("ノードを削除すると、関連するエッジも削除される")
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

@Test("フォーカス中のノードを削除すると、フォーカスが解除される")
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

@Test("グラフを CRUD しても折りたたみルートの状態を維持する")
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

@Test("無効なエッジまたは重複ノードの作成が失敗する")
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

@Test("エッジのデフォルト関係種別は normal になる")
func test_edge_defaultRelationType_isNormal() {
    let edge = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-default"),
        fromNodeID: CanvasNodeID(rawValue: "from"),
        toNodeID: CanvasNodeID(rawValue: "to")
    )
    #expect(edge.relationType == .normal)
}

@Test("createNode はノードを必ず 1 つのエリアにだけ割り当てる")
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

@Test("deleteNode は、削除されたノードを全てのエリア所属から削除する")
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

@Test("重複した添付ファイル IDs は拒否される")
func test_validation_duplicateAttachmentID_rejected() {
    let attachmentID = CanvasAttachmentID(rawValue: "att-1")
    let node = CanvasNode(
        id: CanvasNodeID(rawValue: "node-1"),
        kind: .text,
        text: nil,
        attachments: [
            CanvasAttachment(
                id: attachmentID,
                kind: .image(filePath: "/tmp/a.png"),
                placement: .aboveText
            ),
            CanvasAttachment(
                id: attachmentID,
                kind: .image(filePath: "/tmp/b.png"),
                placement: .aboveText
            ),
        ],
        bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 80)
    )

    let result = CanvasGraphCRUDService.createNode(node, in: .empty)
    #expect(result == .failure(.duplicateAttachmentID(attachmentID)))
}

@Test("画像の添付には空ではないファイル パスが必要である")
func test_validation_emptyImageAttachmentPath_rejected() {
    let node = CanvasNode(
        id: CanvasNodeID(rawValue: "node-1"),
        kind: .text,
        text: nil,
        attachments: [
            CanvasAttachment(
                id: CanvasAttachmentID(rawValue: "att-1"),
                kind: .image(filePath: ""),
                placement: .aboveText
            )
        ],
        bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 80)
    )

    let result = CanvasGraphCRUDService.createNode(node, in: .empty)
    #expect(result == .failure(.invalidAttachmentPayload))
}
