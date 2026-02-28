import Application
import Domain
import Testing

private func expectAlmostEqual(
    _ actual: Double,
    _ expected: Double,
    accuracy: Double = 0.000_1
) {
    #expect(abs(actual - expected) <= accuracy)
}

// Background: Node scaling applies ratio-based size changes to selected nodes in both editing modes.
// Responsibility: Verify selection-targeted scaling behavior and per-mode bounds normalization.
@Test("ApplyCanvasCommandsUseCase: scaleSelectedNodes scales all selected tree nodes")
func test_apply_scaleSelectedNodes_scalesSelectedTreeNodes() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused-tree-node")
    let selectedNodeID = CanvasNodeID(rawValue: "selected-tree-node")
    let areaID = CanvasAreaID(rawValue: "tree-area")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 41)
            ),
            selectedNodeID: CanvasNode(
                id: selectedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 520, y: 40, width: 260, height: 80)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID,
        selectedNodeIDs: [focusedNodeID, selectedNodeID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [focusedNodeID, selectedNodeID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.scaleSelectedNodes(.up)])

    let widthStep = CanvasDefaultNodeDistance.treeNodeWidth * CanvasDefaultNodeDistance.nodeScaleStepRatio
    let heightStep = CanvasDefaultNodeDistance.treeNodeHeight * CanvasDefaultNodeDistance.nodeScaleStepRatio
    let focusedNode = try #require(result.newState.nodesByID[focusedNodeID])
    let selectedNode = try #require(result.newState.nodesByID[selectedNodeID])
    expectAlmostEqual(focusedNode.bounds.width, 220 + widthStep)
    expectAlmostEqual(focusedNode.bounds.height, 41 + heightStep)
    expectAlmostEqual(selectedNode.bounds.width, 260 + widthStep)
    expectAlmostEqual(selectedNode.bounds.height, 80 + heightStep)
}

@Test("ApplyCanvasCommandsUseCase: scaleSelectedNodes keeps diagram node square while scaling down")
func test_apply_scaleSelectedNodes_diagramNode_scalesDownAsSquare() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 220)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        selectedNodeIDs: [nodeID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.scaleSelectedNodes(.down)])

    let scaledNode = try #require(result.newState.nodesByID[nodeID])
    let expectedSide = CanvasDefaultNodeDistance.diagramNodeSide * (1 - CanvasDefaultNodeDistance.nodeScaleStepRatio)
    expectAlmostEqual(scaledNode.bounds.width, expectedSide)
    expectAlmostEqual(scaledNode.bounds.height, expectedSide)
}

@Test("ApplyCanvasCommandsUseCase: scaleSelectedNodes is no-op when no node is selected")
func test_apply_scaleSelectedNodes_noSelection_noOp() async throws {
    let nodeID = CanvasNodeID(rawValue: "tree-node")
    let areaID = CanvasAreaID(rawValue: "tree-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 41)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        selectedNodeIDs: [],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.scaleSelectedNodes(.up)])

    #expect(result.newState == graph)
}

@Test("ApplyCanvasCommandsUseCase: scaleSelectedNodes ignores selections outside focused area")
func test_apply_scaleSelectedNodes_ignoresCrossAreaSelections() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused-tree-node")
    let selectedInFocusedAreaID = CanvasNodeID(rawValue: "selected-tree-node")
    let selectedInOtherAreaID = CanvasNodeID(rawValue: "selected-diagram-node")
    let treeAreaID = CanvasAreaID(rawValue: "tree-area")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 41)
            ),
            selectedInFocusedAreaID: CanvasNode(
                id: selectedInFocusedAreaID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 320, y: 40, width: 260, height: 80)
            ),
            selectedInOtherAreaID: CanvasNode(
                id: selectedInOtherAreaID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 480, width: 220, height: 220)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID,
        selectedNodeIDs: [focusedNodeID, selectedInFocusedAreaID, selectedInOtherAreaID],
        areasByID: [
            treeAreaID: CanvasArea(
                id: treeAreaID, nodeIDs: [focusedNodeID, selectedInFocusedAreaID], editingMode: .tree),
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [selectedInOtherAreaID], editingMode: .diagram),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.scaleSelectedNodes(.up)])

    let widthStep = CanvasDefaultNodeDistance.treeNodeWidth * CanvasDefaultNodeDistance.nodeScaleStepRatio
    let heightStep = CanvasDefaultNodeDistance.treeNodeHeight * CanvasDefaultNodeDistance.nodeScaleStepRatio
    let focusedNode = try #require(result.newState.nodesByID[focusedNodeID])
    let selectedTreeNode = try #require(result.newState.nodesByID[selectedInFocusedAreaID])
    let selectedDiagramNode = try #require(result.newState.nodesByID[selectedInOtherAreaID])
    expectAlmostEqual(focusedNode.bounds.width, 220 + widthStep)
    expectAlmostEqual(focusedNode.bounds.height, 41 + heightStep)
    expectAlmostEqual(selectedTreeNode.bounds.width, 260 + widthStep)
    expectAlmostEqual(selectedTreeNode.bounds.height, 80 + heightStep)
    #expect(selectedDiagramNode.bounds.width == 220)
    #expect(selectedDiagramNode.bounds.height == 220)
}
