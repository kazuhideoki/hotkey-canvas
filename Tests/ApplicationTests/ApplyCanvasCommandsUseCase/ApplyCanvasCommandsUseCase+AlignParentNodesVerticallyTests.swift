import Application
import Domain
import Testing

// Background: Command palette exposes an area-level command to align parent nodes to one vertical line.
// Responsibility: Verify subtree-preserving alignment and overlap resolution in tree/diagram areas.
@Test("ApplyCanvasCommandsUseCase: alignParentNodesVertically aligns parent subtree x positions in tree area")
func test_apply_alignParentNodesVertically_alignsParentSubtreeXInTreeArea() async throws {
    let rootLeftID = CanvasNodeID(rawValue: "root-left")
    let rootRightID = CanvasNodeID(rawValue: "root-right")
    let childID = CanvasNodeID(rawValue: "child")
    let areaID = CanvasAreaID.defaultTree

    let graph = CanvasGraph(
        nodesByID: [
            rootLeftID: CanvasNode(
                id: rootLeftID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 220, height: 120)
            ),
            rootRightID: CanvasNode(
                id: rootRightID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 280, width: 220, height: 120)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 520, y: 280, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-right-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-right-child"),
                fromNodeID: rootRightID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootRightID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [rootLeftID, rootRightID, childID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.alignParentNodesVertically])

    let rootLeft = try #require(result.newState.nodesByID[rootLeftID])
    let rootRight = try #require(result.newState.nodesByID[rootRightID])
    let child = try #require(result.newState.nodesByID[childID])
    #expect(rootLeft.bounds.x == 40)
    #expect(rootRight.bounds.x == 40)
    #expect(child.bounds.x == 360)
}

@Test("ApplyCanvasCommandsUseCase: alignParentNodesVertically aligns parent subtree x positions in diagram area")
func test_apply_alignParentNodesVertically_alignsParentSubtreeXInDiagramArea() async throws {
    let parentLeftID = CanvasNodeID(rawValue: "parent-left")
    let parentRightID = CanvasNodeID(rawValue: "parent-right")
    let childID = CanvasNodeID(rawValue: "child")
    let areaID = CanvasAreaID(rawValue: "diagram-area")

    let graph = CanvasGraph(
        nodesByID: [
            parentLeftID: CanvasNode(
                id: parentLeftID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 40, width: 220, height: 120)
            ),
            parentRightID: CanvasNode(
                id: parentRightID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 260, y: 240, width: 220, height: 120)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 520, y: 240, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-parent-right-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-parent-right-child"),
                fromNodeID: parentRightID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: parentRightID,
        areasByID: [
            areaID: CanvasArea(
                id: areaID,
                nodeIDs: [parentLeftID, parentRightID, childID],
                editingMode: .diagram
            )
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.alignParentNodesVertically])

    let parentLeft = try #require(result.newState.nodesByID[parentLeftID])
    let parentRight = try #require(result.newState.nodesByID[parentRightID])
    let child = try #require(result.newState.nodesByID[childID])
    #expect(parentLeft.bounds.x == 100)
    #expect(parentRight.bounds.x == 100)
    #expect(child.bounds.x == 360)
}

@Test("ApplyCanvasCommandsUseCase: alignParentNodesVertically resolves subtree overlap while keeping roots aligned")
func test_apply_alignParentNodesVertically_resolvesSubtreeOverlapWhileKeepingRootsAligned() async throws {
    let rootTopID = CanvasNodeID(rawValue: "root-top")
    let rootBottomID = CanvasNodeID(rawValue: "root-bottom")
    let topChildID = CanvasNodeID(rawValue: "top-child")
    let bottomChildID = CanvasNodeID(rawValue: "bottom-child")
    let graph = makeOverlapFixtureGraph(
        rootTopID: rootTopID,
        rootBottomID: rootBottomID,
        topChildID: topChildID,
        bottomChildID: bottomChildID
    )

    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)
    let result = try await sut.apply(commands: [.alignParentNodesVertically])

    let rootTop = try #require(result.newState.nodesByID[rootTopID])
    let rootBottom = try #require(result.newState.nodesByID[rootBottomID])
    let topChild = try #require(result.newState.nodesByID[topChildID])
    let bottomChild = try #require(result.newState.nodesByID[bottomChildID])
    #expect(rootTop.bounds.x == 80)
    #expect(rootBottom.bounds.x == 80)
    #expect(topChild.bounds.y == 40)
    #expect(bottomChild.bounds.y == 192)
    #expect(rootBottom.bounds.y == 192)
}

@Test(
    "ApplyCanvasCommandsUseCase: alignParentNodesVertically does not move shared descendant twice in multi-parent graph"
)
func test_apply_alignParentNodesVertically_doesNotMoveSharedDescendantTwice() async throws {
    let rootTopID = CanvasNodeID(rawValue: "root-top")
    let rootBottomID = CanvasNodeID(rawValue: "root-bottom")
    let topChildID = CanvasNodeID(rawValue: "top-child")
    let bottomChildID = CanvasNodeID(rawValue: "bottom-child")
    let sharedDescendantID = CanvasNodeID(rawValue: "shared-descendant")
    let graph = makeSharedDescendantFixtureGraph(
        rootTopID: rootTopID,
        rootBottomID: rootBottomID,
        topChildID: topChildID,
        bottomChildID: bottomChildID,
        sharedDescendantID: sharedDescendantID
    )

    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)
    let result = try await sut.apply(commands: [.alignParentNodesVertically])

    let rootBottom = try #require(result.newState.nodesByID[rootBottomID])
    let bottomChild = try #require(result.newState.nodesByID[bottomChildID])
    let sharedDescendant = try #require(result.newState.nodesByID[sharedDescendantID])
    #expect(rootBottom.bounds.y == 232)
    #expect(bottomChild.bounds.y == 232)
    #expect(sharedDescendant.bounds.y == 80)
}

private func makeOverlapFixtureGraph(
    rootTopID: CanvasNodeID,
    rootBottomID: CanvasNodeID,
    topChildID: CanvasNodeID,
    bottomChildID: CanvasNodeID
) -> CanvasGraph {
    let areaID = CanvasAreaID.defaultTree
    return CanvasGraph(
        nodesByID: [
            rootTopID: CanvasNode(
                id: rootTopID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 80, y: 40, width: 220, height: 120)
            ),
            topChildID: CanvasNode(
                id: topChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 320, y: 40, width: 220, height: 120)
            ),
            rootBottomID: CanvasNode(
                id: rootBottomID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 80, y: 80, width: 220, height: 120)
            ),
            bottomChildID: CanvasNode(
                id: bottomChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 320, y: 80, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-top"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-top"),
                fromNodeID: rootTopID,
                toNodeID: topChildID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-bottom"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-bottom"),
                fromNodeID: rootBottomID,
                toNodeID: bottomChildID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: rootBottomID,
        areasByID: [
            areaID: CanvasArea(
                id: areaID,
                nodeIDs: [rootTopID, topChildID, rootBottomID, bottomChildID],
                editingMode: .tree
            )
        ]
    )
}

private func makeSharedDescendantFixtureGraph(
    rootTopID: CanvasNodeID,
    rootBottomID: CanvasNodeID,
    topChildID: CanvasNodeID,
    bottomChildID: CanvasNodeID,
    sharedDescendantID: CanvasNodeID
) -> CanvasGraph {
    let areaID = CanvasAreaID.defaultTree
    return CanvasGraph(
        nodesByID: makeSharedDescendantFixtureNodes(
            rootTopID: rootTopID,
            rootBottomID: rootBottomID,
            topChildID: topChildID,
            bottomChildID: bottomChildID,
            sharedDescendantID: sharedDescendantID
        ),
        edgesByID: makeSharedDescendantFixtureEdges(
            rootTopID: rootTopID,
            rootBottomID: rootBottomID,
            topChildID: topChildID,
            bottomChildID: bottomChildID,
            sharedDescendantID: sharedDescendantID
        ),
        focusedNodeID: rootBottomID,
        areasByID: [
            areaID: CanvasArea(
                id: areaID,
                nodeIDs: [rootTopID, rootBottomID, topChildID, bottomChildID, sharedDescendantID],
                editingMode: .tree
            )
        ]
    )
}

private func makeSharedDescendantFixtureNodes(
    rootTopID: CanvasNodeID,
    rootBottomID: CanvasNodeID,
    topChildID: CanvasNodeID,
    bottomChildID: CanvasNodeID,
    sharedDescendantID: CanvasNodeID
) -> [CanvasNodeID: CanvasNode] {
    [
        rootTopID: CanvasNode(
            id: rootTopID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 80, y: 40, width: 220, height: 120)
        ),
        rootBottomID: CanvasNode(
            id: rootBottomID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 80, y: 80, width: 220, height: 120)
        ),
        topChildID: CanvasNode(
            id: topChildID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 320, y: 40, width: 220, height: 120)
        ),
        bottomChildID: CanvasNode(
            id: bottomChildID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 320, y: 80, width: 220, height: 120)
        ),
        sharedDescendantID: CanvasNode(
            id: sharedDescendantID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 560, y: 80, width: 220, height: 120)
        ),
    ]
}

private func makeSharedDescendantFixtureEdges(
    rootTopID: CanvasNodeID,
    rootBottomID: CanvasNodeID,
    topChildID: CanvasNodeID,
    bottomChildID: CanvasNodeID,
    sharedDescendantID: CanvasNodeID
) -> [CanvasEdgeID: CanvasEdge] {
    [
        CanvasEdgeID(rawValue: "edge-root-top"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-root-top"),
            fromNodeID: rootTopID,
            toNodeID: topChildID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-root-bottom"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-root-bottom"),
            fromNodeID: rootBottomID,
            toNodeID: bottomChildID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-top-shared"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-top-shared"),
            fromNodeID: topChildID,
            toNodeID: sharedDescendantID,
            relationType: .parentChild
        ),
        CanvasEdgeID(rawValue: "edge-bottom-shared"): CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-bottom-shared"),
            fromNodeID: bottomChildID,
            toNodeID: sharedDescendantID,
            relationType: .parentChild
        ),
    ]
}
