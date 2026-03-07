import Application
import Domain
import Testing

private func nodesOverlap(_ lhs: CanvasNode, _ rhs: CanvasNode) -> Bool {
    lhs.bounds.x < rhs.bounds.x + rhs.bounds.width
        && lhs.bounds.x + lhs.bounds.width > rhs.bounds.x
        && lhs.bounds.y < rhs.bounds.y + rhs.bounds.height
        && lhs.bounds.y + lhs.bounds.height > rhs.bounds.y
}

@Test("ApplyCanvasCommandsUseCase: alignSelectedNodes horizontal aligns selected diagram nodes to focused center y")
func test_apply_alignSelectedNodes_horizontal_alignsSelectedDiagramNodes() async throws {
    let focusedID = CanvasNodeID(rawValue: "focused-diagram-node")
    let selectedID = CanvasNodeID(rawValue: "selected-diagram-node")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 130, width: 220, height: 220)
            ),
            selectedID: CanvasNode(
                id: selectedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 380, y: 360, width: 180, height: 120)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID],
        areasByID: [
            diagramAreaID: CanvasArea(
                id: diagramAreaID,
                nodeIDs: [focusedID, selectedID],
                editingMode: .diagram
            )
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.alignSelectedNodes(.horizontal)])

    let focusedNode = try #require(result.newState.nodesByID[focusedID])
    let alignedNode = try #require(result.newState.nodesByID[selectedID])
    let focusedCenterY = focusedNode.bounds.y + (focusedNode.bounds.height / 2)
    let alignedCenterY = alignedNode.bounds.y + (alignedNode.bounds.height / 2)
    #expect(alignedCenterY == focusedCenterY)
    #expect(alignedNode.bounds.x == 380)
}

@Test("ApplyCanvasCommandsUseCase: alignSelectedNodes vertical aligns selected diagram nodes to focused center x")
func test_apply_alignSelectedNodes_vertical_alignsSelectedDiagramNodes() async throws {
    let focusedID = CanvasNodeID(rawValue: "focused-diagram-node")
    let selectedID = CanvasNodeID(rawValue: "selected-diagram-node")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 120, y: 80, width: 220, height: 220)
            ),
            selectedID: CanvasNode(
                id: selectedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 480, y: 320, width: 140, height: 180)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID],
        areasByID: [
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [focusedID, selectedID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.alignSelectedNodes(.vertical)])

    let focusedNode = try #require(result.newState.nodesByID[focusedID])
    let alignedNode = try #require(result.newState.nodesByID[selectedID])
    let focusedCenterX = focusedNode.bounds.x + (focusedNode.bounds.width / 2)
    let alignedCenterX = alignedNode.bounds.x + (alignedNode.bounds.width / 2)
    #expect(alignedCenterX == focusedCenterX)
    #expect(alignedNode.bounds.y == 320)
}

@Test("ApplyCanvasCommandsUseCase: alignSelectedNodes resolves overlap while preserving horizontal alignment")
func test_apply_alignSelectedNodes_horizontal_resolvesOverlap() async throws {
    let focusedID = CanvasNodeID(rawValue: "focused-diagram-node")
    let selectedID = CanvasNodeID(rawValue: "selected-diagram-node")
    let diagramAreaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 120, width: 220, height: 220)
            ),
            selectedID: CanvasNode(
                id: selectedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 250, y: 360, width: 220, height: 120)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID],
        areasByID: [
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [focusedID, selectedID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.alignSelectedNodes(.horizontal)])

    let focusedNode = try #require(result.newState.nodesByID[focusedID])
    let alignedNode = try #require(result.newState.nodesByID[selectedID])
    let focusedCenterY = focusedNode.bounds.y + (focusedNode.bounds.height / 2)
    let alignedCenterY = alignedNode.bounds.y + (alignedNode.bounds.height / 2)
    #expect(alignedCenterY == focusedCenterY)
    #expect(!nodesOverlap(focusedNode, alignedNode))
    #expect(alignedNode.bounds.x > graph.nodesByID[selectedID]?.bounds.x ?? 0)
}

@Test("ApplyCanvasCommandsUseCase: alignSelectedNodes is unsupported in tree area")
func test_apply_alignSelectedNodes_treeArea_isUnsupported() async throws {
    let focusedID = CanvasNodeID(rawValue: "focused-tree-node")
    let selectedID = CanvasNodeID(rawValue: "selected-tree-node")
    let treeAreaID = CanvasAreaID(rawValue: "tree-area")
    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 41)
            ),
            selectedID: CanvasNode(
                id: selectedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 320, y: 120, width: 220, height: 41)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID],
        areasByID: [
            treeAreaID: CanvasArea(id: treeAreaID, nodeIDs: [focusedID, selectedID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    do {
        _ = try await sut.apply(commands: [.alignSelectedNodes(.vertical)])
        Issue.record("Expected unsupported command error")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .unsupportedCommandInMode(mode: .tree, command: .alignSelectedNodes(.vertical)))
    }
}
