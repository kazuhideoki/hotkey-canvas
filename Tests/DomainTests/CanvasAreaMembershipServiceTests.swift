import Domain
import Testing

// Background: Area-mode dispatch needs deterministic and validated node membership.
// Responsibility: Verify membership validation and reassignment behavior.
@Test("ノードがどのエリアにも属していないとき、validate は失敗する")
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

@Test("ノードが複数のエリアに属しているとき、validate は失敗する")
func test_validate_failsWhenNodeBelongsToMultipleAreas() throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let firstAreaID = CanvasAreaID(rawValue: "area-1")
    let secondAreaID = CanvasAreaID(rawValue: "area-2")
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
            firstAreaID: CanvasArea(id: firstAreaID, nodeIDs: [nodeID], editingMode: .tree),
            secondAreaID: CanvasArea(id: secondAreaID, nodeIDs: [nodeID], editingMode: .diagram),
        ]
    )

    do {
        try CanvasAreaMembershipService.validate(in: graph).get()
        Issue.record("Expected nodeAssignedToMultipleAreas")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .nodeAssignedToMultipleAreas(nodeID))
    }
}

@Test("assign すると、ノードの所属エリアが移動する")
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

@Test("フォーカス中のノードがどのエリアにも属していないとき、focusedAreaID は失敗する")
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

@Test("フォーカス中のノードが複数のエリアに属しているとき、focusedAreaID は失敗する")
func test_focusedAreaID_failsWhenFocusedNodeBelongsToMultipleAreas() throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let firstAreaID = CanvasAreaID(rawValue: "area-1")
    let secondAreaID = CanvasAreaID(rawValue: "area-2")
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
            firstAreaID: CanvasArea(id: firstAreaID, nodeIDs: [focusedNodeID], editingMode: .tree),
            secondAreaID: CanvasArea(id: secondAreaID, nodeIDs: [focusedNodeID], editingMode: .diagram),
        ]
    )

    do {
        try CanvasAreaMembershipService.focusedAreaID(in: graph).get()
        Issue.record("Expected nodeAssignedToMultipleAreas")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .nodeAssignedToMultipleAreas(focusedNodeID))
    }
}

@Test("フォーカス中の要素がエリアのとき、focusedAreaID はそのエリアを優先する")
func test_focusedAreaID_prefersFocusedAreaElement() throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let areaIDFromFocus = CanvasAreaID(rawValue: "focused-area")
    let areaIDFromNode = CanvasAreaID(rawValue: "node-area")
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
        focusedElement: .area(areaIDFromFocus),
        areasByID: [
            areaIDFromFocus: CanvasArea(id: areaIDFromFocus, nodeIDs: [], editingMode: .diagram),
            areaIDFromNode: CanvasArea(id: areaIDFromNode, nodeIDs: [focusedNodeID], editingMode: .tree),
        ]
    )

    let result = try CanvasAreaMembershipService.focusedAreaID(in: graph).get()

    #expect(result == areaIDFromFocus)
}

@Test("フォーカス中の要素が存在しないエリアを指すとき、focusedAreaID は失敗する")
func test_focusedAreaID_failsWhenFocusedAreaElementIsMissing() throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let missingAreaID = CanvasAreaID(rawValue: "missing-area")
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
        focusedElement: .area(missingAreaID),
        areasByID: [
            .defaultTree: CanvasArea(id: .defaultTree, nodeIDs: [focusedNodeID], editingMode: .tree)
        ]
    )

    do {
        try CanvasAreaMembershipService.focusedAreaID(in: graph).get()
        Issue.record("Expected areaNotFound")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .areaNotFound(missingAreaID))
    }
}

@Test("createArea すると、初期メンバーは既存エリアから新しいエリアへ移る")
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

@Test("assign によってエリア間エッジが生まれるとき、assign は失敗する")
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

@Test("createArea によってエリア間エッジが生まれるとき、createArea は失敗する")
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

@Test("convertFocusedAreaMode すると、フォーカス中のエリアのモードが更新される")
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

@Test("変換先モードが現在と同じとき、convertFocusedAreaMode は何もしない")
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

@Test("toggleFocusedAreaEdgeShapeStyle すると、フォーカス中のエリアの線形状が順番に切り替わる")
func test_toggleFocusedAreaEdgeShapeStyle_cyclesFocusedAreaShapeStyle() throws {
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
            areaID: CanvasArea(id: areaID, nodeIDs: [focusedNodeID], editingMode: .diagram, edgeShapeStyle: .legacy)
        ]
    )

    let toggled = try CanvasAreaMembershipService.toggleFocusedAreaEdgeShapeStyle(in: graph).get()
    #expect(toggled.areasByID[areaID]?.edgeShapeStyle == .curved)

    let toggledAgain = try CanvasAreaMembershipService.toggleFocusedAreaEdgeShapeStyle(in: toggled).get()
    #expect(toggledAgain.areasByID[areaID]?.edgeShapeStyle == .straight)

    let toggledThird = try CanvasAreaMembershipService.toggleFocusedAreaEdgeShapeStyle(in: toggledAgain).get()
    #expect(toggledThird.areasByID[areaID]?.edgeShapeStyle == .legacy)
}
