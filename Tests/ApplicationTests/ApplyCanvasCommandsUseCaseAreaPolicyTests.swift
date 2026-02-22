import Application
import Domain
import Testing

// Background: Phase-1 area mode requires command dispatch by focused area policy.
// Responsibility: Verify mode-specific command gating and area-data validation in apply entry.
@Test("ApplyCanvasCommandsUseCase: diagram area maps addChildNode command to addNode behavior")
func test_apply_diagramArea_mapsAddChildNodeToAddNodeBehavior() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addChildNode])

    #expect(result.newState.nodesByID.count == 2)
    let focusedNodeID = try #require(result.newState.focusedNodeID)
    #expect(result.newState.nodesByID[focusedNodeID] != nil)
    #expect(result.newState.edgesByID.count == 1)
    let edge = try #require(result.newState.edgesByID.values.first)
    #expect(edge.fromNodeID == nodeID)
    #expect(edge.toNodeID == focusedNodeID)
    #expect(edge.relationType == .normal)
}

@Test("ApplyCanvasCommandsUseCase: diagram area maps addChildNode to addNode when focus is nil and area is unique")
func test_apply_diagramArea_mapsAddChildNodeWithoutFocusWhenSingleArea() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [:],
        edgesByID: [:],
        focusedNodeID: nil,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addChildNode])

    #expect(result.newState.nodesByID.count == 1)
    #expect(result.newState.edgesByID.isEmpty)
    let focusedNodeID = try #require(result.newState.focusedNodeID)
    #expect(result.newState.areasByID[areaID]?.nodeIDs == [focusedNodeID])
}

@Test(
    "ApplyCanvasCommandsUseCase: diagram area moveNode relocates focused node to directional slot around connected node"
)
func test_apply_diagramArea_moveNodeRelocatesFocusedNodeAroundConnectedNode() async throws {
    let anchorID = CanvasNodeID(rawValue: "diagram-anchor")
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let connectionEdgeID = CanvasEdgeID(rawValue: "edge-anchor-node")
    let graph = CanvasGraph(
        nodesByID: [
            anchorID: CanvasNode(
                id: anchorID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            ),
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            connectionEdgeID: CanvasEdge(
                id: connectionEdgeID,
                fromNodeID: anchorID,
                toNodeID: nodeID,
                relationType: .normal
            )
        ],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [anchorID, nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.right)])

    let movedNode = try #require(result.newState.nodesByID[nodeID])
    #expect(movedNode.bounds.x == 440)
    #expect(movedNode.bounds.y == 0)
}

@Test("ApplyCanvasCommandsUseCase: diagram area nudgeNode nudges focused node")
func test_apply_diagramArea_nudgeNodeMovesFocusedNodeByStep() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.nudgeNode(.right)])

    let movedNode = try #require(result.newState.nodesByID[nodeID])
    #expect(movedNode.bounds.x == 260)
    #expect(movedNode.bounds.y == 40)
}

@Test("ApplyCanvasCommandsUseCase: diagram area nudgeNode does not relayout neighboring nodes")
func test_apply_diagramArea_nudgeNodeDoesNotRelayoutNeighboringNodes() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused-diagram-node")
    let neighborNodeID = CanvasNodeID(rawValue: "neighbor-diagram-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            ),
            neighborNodeID: CanvasNode(
                id: neighborNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 60, y: 40, width: 220, height: 120)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [focusedNodeID, neighborNodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.nudgeNode(.right)])

    let movedNode = try #require(result.newState.nodesByID[focusedNodeID])
    let neighborNode = try #require(result.newState.nodesByID[neighborNodeID])
    #expect(movedNode.bounds.x == 260)
    #expect(movedNode.bounds.y == 40)
    #expect(neighborNode.bounds.x == 60)
    #expect(neighborNode.bounds.y == 40)
}

@Test("ApplyCanvasCommandsUseCase: tree area nudgeNode is no-op")
func test_apply_treeArea_nudgeNodeIsNoOp() async throws {
    let nodeID = CanvasNodeID(rawValue: "tree-node")
    let areaID = CanvasAreaID(rawValue: "tree-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.nudgeNode(.right)])

    #expect(result.newState == graph)
}

@Test("ApplyCanvasCommandsUseCase: diagram area rejects copyFocusedSubtree command")
func test_apply_diagramArea_rejectsCopyFocusedSubtreeCommand() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    do {
        _ = try await sut.apply(commands: [.copyFocusedSubtree])
        Issue.record("Expected unsupported command error")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .unsupportedCommandInMode(mode: .diagram, command: .copyFocusedSubtree))
    }
}

@Test("ApplyCanvasCommandsUseCase: diagram area allows assignNodesToArea command")
func test_apply_diagramArea_allowsAssignNodesToAreaCommand() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram-area")
    let targetAreaID = CanvasAreaID(rawValue: "target-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [nodeID], editingMode: .diagram),
            targetAreaID: CanvasArea(id: targetAreaID, nodeIDs: [], editingMode: .tree),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.assignNodesToArea(nodeIDs: [nodeID], areaID: targetAreaID)])

    #expect(result.newState.areasByID[targetAreaID]?.nodeIDs == [nodeID])
    #expect(result.newState.areasByID[diagramAreaID]?.nodeIDs.isEmpty == true)
}

@Test("ApplyCanvasCommandsUseCase: diagram area allows createArea command")
func test_apply_diagramArea_allowsCreateAreaCommand() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram-area")
    let newAreaID = CanvasAreaID(rawValue: "new-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(
        commands: [
            .createArea(id: newAreaID, mode: .diagram, nodeIDs: [nodeID])
        ]
    )

    #expect(result.newState.areasByID[newAreaID]?.nodeIDs == [nodeID])
    #expect(result.newState.areasByID[diagramAreaID]?.nodeIDs.isEmpty == true)
}

@Test("ApplyCanvasCommandsUseCase: addNode fails when no focus and multiple areas exist")
func test_apply_addNode_failsWhenNoFocusAndMultipleAreasExist() async throws {
    let areaA = CanvasAreaID(rawValue: "area-a")
    let areaB = CanvasAreaID(rawValue: "area-b")
    let graph = CanvasGraph(
        nodesByID: [:],
        edgesByID: [:],
        focusedNodeID: nil,
        areasByID: [
            areaA: CanvasArea(id: areaA, nodeIDs: [], editingMode: .tree),
            areaB: CanvasArea(id: areaB, nodeIDs: [], editingMode: .diagram),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    do {
        _ = try await sut.apply(commands: [.addNode])
        Issue.record("Expected areaResolutionAmbiguousForAddNode")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .areaResolutionAmbiguousForAddNode)
    }
}

@Test("ApplyCanvasCommandsUseCase: apply fails when graph has nodes but no area data")
func test_apply_failsWhenAreaDataMissing() async throws {
    let nodeID = CanvasNodeID(rawValue: "node-1")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [:]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    do {
        _ = try await sut.apply(commands: [.moveFocus(.right)])
        Issue.record("Expected areaDataMissing")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .areaDataMissing)
    }
}

@Test("ApplyCanvasCommandsUseCase: convertFocusedAreaMode converts focused area mode")
func test_apply_convertFocusedAreaMode_convertsFocusedAreaMode() async throws {
    let nodeID = CanvasNodeID(rawValue: "focused")
    let areaID = CanvasAreaID(rawValue: "area-1")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.convertFocusedAreaMode(to: .diagram)])

    #expect(result.newState.areasByID[areaID]?.editingMode == .diagram)
    let convertedNode = try #require(result.newState.nodesByID[nodeID])
    #expect(convertedNode.bounds.width == 220)
    #expect(convertedNode.bounds.height == 220)
}
