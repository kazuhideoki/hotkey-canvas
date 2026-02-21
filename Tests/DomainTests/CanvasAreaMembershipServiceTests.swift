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

@Test("CanvasAreaMembershipService: createArea reassigns initial members from existing areas")
func test_createArea_reassignsInitialMembersFromExistingAreas() throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let sourceAreaID = CanvasAreaID(rawValue: "source")
    let newAreaID = CanvasAreaID(rawValue: "new")
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
            sourceAreaID: CanvasArea(id: sourceAreaID, nodeIDs: [nodeID], editingMode: .tree)
        ]
    )

    let created = try CanvasAreaMembershipService.createArea(
        id: newAreaID,
        mode: .diagram,
        nodeIDs: [nodeID],
        in: graph
    ).get()

    #expect(created.areasByID[sourceAreaID]?.nodeIDs.contains(nodeID) == false)
    #expect(created.areasByID[newAreaID]?.nodeIDs == [nodeID])
    try CanvasAreaMembershipService.validate(in: created).get()
}

@Test("CanvasAreaMembershipService: assign fails when cross-area edge would be introduced")
func test_assign_failsWhenCrossAreaEdgeWouldBeIntroduced() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeID = CanvasEdgeID(rawValue: "edge-parent-child")
    let treeAreaID = CanvasAreaID(rawValue: "tree")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram")
    let graph = CanvasGraph(
        nodesByID: [
            parentID: CanvasNode(
                id: parentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 80)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 260, y: 0, width: 200, height: 80)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: parentID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: parentID,
        areasByID: [
            treeAreaID: CanvasArea(id: treeAreaID, nodeIDs: [parentID, childID], editingMode: .tree),
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [], editingMode: .diagram),
        ]
    )

    do {
        _ = try CanvasAreaMembershipService.assign(nodeIDs: [childID], to: diagramAreaID, in: graph).get()
        Issue.record("Expected crossAreaEdgeForbidden")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .crossAreaEdgeForbidden(edgeID))
    }
}

@Test("CanvasAreaMembershipService: createArea fails when cross-area edge would be introduced")
func test_createArea_failsWhenCrossAreaEdgeWouldBeIntroduced() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeID = CanvasEdgeID(rawValue: "edge-parent-child")
    let sourceAreaID = CanvasAreaID(rawValue: "source")
    let newAreaID = CanvasAreaID(rawValue: "new")
    let graph = CanvasGraph(
        nodesByID: [
            parentID: CanvasNode(
                id: parentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 80)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 260, y: 0, width: 200, height: 80)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: parentID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: parentID,
        areasByID: [
            sourceAreaID: CanvasArea(id: sourceAreaID, nodeIDs: [parentID, childID], editingMode: .tree)
        ]
    )

    do {
        _ = try CanvasAreaMembershipService.createArea(
            id: newAreaID,
            mode: .diagram,
            nodeIDs: [childID],
            in: graph
        ).get()
        Issue.record("Expected crossAreaEdgeForbidden")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .crossAreaEdgeForbidden(edgeID))
    }
}

@Test("CanvasAreaMembershipService: convertFocusedAreaMode updates focused area mode")
func test_convertFocusedAreaMode_updatesFocusedAreaMode() throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let areaID = CanvasAreaID(rawValue: "area-1")
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
            areaID: CanvasArea(id: areaID, nodeIDs: [focusedNodeID], editingMode: .tree)
        ]
    )

    let converted = try CanvasAreaMembershipService.convertFocusedAreaMode(
        to: .diagram,
        in: graph
    ).get()

    #expect(converted.areasByID[areaID]?.editingMode == .diagram)
}

@Test("CanvasAreaMembershipService: convertFocusedAreaMode no-ops when target mode is same")
func test_convertFocusedAreaMode_noOpsWhenTargetModeIsSame() throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let areaID = CanvasAreaID(rawValue: "area-1")
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
            areaID: CanvasArea(id: areaID, nodeIDs: [focusedNodeID], editingMode: .diagram)
        ]
    )

    let converted = try CanvasAreaMembershipService.convertFocusedAreaMode(
        to: .diagram,
        in: graph
    ).get()

    #expect(converted == graph)
}
