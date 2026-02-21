import Domain
import Testing

// Background: Area-mode dispatch needs deterministic and validated node membership.
// Responsibility: Verify membership validation and reassignment behavior.
@Test("CanvasAreaMembershipService: validate fails when node has no area")
func test_validate_failsWhenNodeHasNoArea() throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [:]
    )

    do {
        try CanvasAreaMembershipService.validate(in: graph).get()
        Issue.record("Expected areaDataMissing")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .areaDataMissing)
    }
}

@Test("CanvasAreaMembershipService: assign moves membership between areas")
func test_assign_movesMembershipBetweenAreas() throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let treeAreaID = CanvasAreaID(rawValue: "tree-a")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram-a")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            treeAreaID: CanvasArea(id: treeAreaID, nodeIDs: [nodeID], editingMode: .tree),
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [], editingMode: .diagram),
        ]
    )

    let movedGraph = try CanvasAreaMembershipService.assign(
        nodeIDs: [nodeID],
        to: diagramAreaID,
        in: graph
    ).get()

    #expect(movedGraph.areasByID[treeAreaID]?.nodeIDs.contains(nodeID) == false)
    #expect(movedGraph.areasByID[diagramAreaID]?.nodeIDs.contains(nodeID) == true)
}

@Test("CanvasAreaMembershipService: focusedAreaID fails when focused node is unassigned")
func test_focusedAreaID_failsWhenFocusedNodeIsUnassigned() throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID,
        areasByID: [
            .defaultTree: CanvasArea(id: .defaultTree, nodeIDs: [], editingMode: .tree)
        ]
    )

    do {
        try CanvasAreaMembershipService.focusedAreaID(in: graph).get()
        Issue.record("Expected focusedNodeNotAssignedToArea")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .focusedNodeNotAssignedToArea(focusedNodeID))
    }
}
