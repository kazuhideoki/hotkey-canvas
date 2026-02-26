import Application
import Domain
import Testing

// Background: Command palette provides one command to vertically align area blocks.
// Responsibility: Verify cross-area left alignment while preserving intra-area node layout.
@Test("ApplyCanvasCommandsUseCase: alignParentNodesVertically aligns all areas to one left column")
func test_apply_alignParentNodesVertically_alignsAllAreasToOneLeftColumn() async throws {
    let fixture = makeMultiAreaFixtureGraph()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture)

    let result = try await sut.apply(commands: [.alignParentNodesVertically])

    let leftRoot = try #require(result.newState.nodesByID[CanvasNodeID(rawValue: "left-root")])
    let leftChild = try #require(result.newState.nodesByID[CanvasNodeID(rawValue: "left-child")])
    let rightRoot = try #require(result.newState.nodesByID[CanvasNodeID(rawValue: "right-root")])
    let rightChild = try #require(result.newState.nodesByID[CanvasNodeID(rawValue: "right-child")])
    #expect(leftRoot.bounds.x == 40)
    #expect(leftChild.bounds.x == 280)
    #expect(rightRoot.bounds.x == 40)
    #expect(rightChild.bounds.x == 260)
    #expect(leftRoot.bounds.y == 40)
    #expect(rightRoot.bounds.y == 222)
    #expect(rightChild.bounds.y == 252)
}

@Test("ApplyCanvasCommandsUseCase: alignParentNodesVertically keeps relative positions inside each area")
func test_apply_alignParentNodesVertically_preservesRelativePositionsInsideEachArea() async throws {
    let fixture = makeMultiAreaFixtureGraph()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: fixture)

    let result = try await sut.apply(commands: [.alignParentNodesVertically])
    let before = fixture.nodesByID
    let after = result.newState.nodesByID

    try assertRelativeOffset(
        from: CanvasNodeID(rawValue: "left-root"),
        to: CanvasNodeID(rawValue: "left-child"),
        before: before,
        after: after
    )
    try assertRelativeOffset(
        from: CanvasNodeID(rawValue: "right-root"),
        to: CanvasNodeID(rawValue: "right-child"),
        before: before,
        after: after
    )
}

@Test("ApplyCanvasCommandsUseCase: alignParentNodesVertically is no-op when only one area exists")
func test_apply_alignParentNodesVertically_isNoOpWhenOnlyOneAreaExists() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let areaID = CanvasAreaID.defaultTree
    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 120, y: 100, width: 220, height: 120)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 360, y: 130, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [rootID, childID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.alignParentNodesVertically])

    #expect(result.newState == graph)
}

private func makeMultiAreaFixtureGraph() -> CanvasGraph {
    let leftRootID = CanvasNodeID(rawValue: "left-root")
    let leftChildID = CanvasNodeID(rawValue: "left-child")
    let rightRootID = CanvasNodeID(rawValue: "right-root")
    let rightChildID = CanvasNodeID(rawValue: "right-child")
    let leftAreaID = CanvasAreaID(rawValue: "left-area")
    let rightAreaID = CanvasAreaID(rawValue: "right-area")
    return CanvasGraph(
        nodesByID: [
            leftRootID: CanvasNode(
                id: leftRootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            ),
            leftChildID: CanvasNode(
                id: leftChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 280, y: 70, width: 220, height: 120)
            ),
            rightRootID: CanvasNode(
                id: rightRootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 420, y: 40, width: 220, height: 120)
            ),
            rightChildID: CanvasNode(
                id: rightChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 640, y: 70, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-left"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-left"),
                fromNodeID: leftRootID,
                toNodeID: leftChildID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-right"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-right"),
                fromNodeID: rightRootID,
                toNodeID: rightChildID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: rightRootID,
        areasByID: [
            leftAreaID: CanvasArea(id: leftAreaID, nodeIDs: [leftRootID, leftChildID], editingMode: .tree),
            rightAreaID: CanvasArea(id: rightAreaID, nodeIDs: [rightRootID, rightChildID], editingMode: .diagram),
        ]
    )
}

private func assertRelativeOffset(
    from sourceID: CanvasNodeID,
    to targetID: CanvasNodeID,
    before: [CanvasNodeID: CanvasNode],
    after: [CanvasNodeID: CanvasNode]
) throws {
    let sourceBefore = try #require(before[sourceID])
    let targetBefore = try #require(before[targetID])
    let sourceAfter = try #require(after[sourceID])
    let targetAfter = try #require(after[targetID])
    #expect(targetAfter.bounds.x - sourceAfter.bounds.x == targetBefore.bounds.x - sourceBefore.bounds.x)
    #expect(targetAfter.bounds.y - sourceAfter.bounds.y == targetBefore.bounds.y - sourceBefore.bounds.y)
}
