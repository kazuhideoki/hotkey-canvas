// Background: Parent-child trees should be recomputed globally after structural and node-size changes.
// Responsibility: Verify deterministic symmetric tree layout and spacing guarantees.
import Domain
import Testing

@Test("CanvasTreeLayoutService: children are laid out symmetrically and without overlap")
func test_relayoutParentChildTrees_childrenAreSymmetric() throws {
    let fixture = makeSymmetricLayoutFixture()

    let result = CanvasTreeLayoutService.relayoutParentChildTrees(
        in: fixture.graph,
        verticalSpacing: 24,
        horizontalSpacing: 32
    )

    let root = try #require(result[fixture.rootID])
    let childA = try #require(result[fixture.childAID])
    let childB = try #require(result[fixture.childBID])
    let childC = try #require(result[fixture.childCID])

    #expect(root.x == 100)
    #expect(childA.x == root.x + root.width + 32)
    #expect(childB.x == root.x + root.width + 32)
    #expect(childC.x == root.x + root.width + 32)

    #expect(childA.y + childA.height + 24 <= childB.y)
    #expect(childB.y + childB.height + 24 <= childC.y)

    let childrenTop = min(childA.y, childB.y, childC.y)
    let childrenBottom = max(
        childA.y + childA.height,
        childB.y + childB.height,
        childC.y + childC.height
    )
    let expectedRootCenterY = (childrenTop + childrenBottom) / 2
    let actualRootCenterY = root.y + (root.height / 2)
    #expect(abs(actualRootCenterY - expectedRootCenterY) < 0.0001)
}

@Test("CanvasTreeLayoutService: root anchor position is preserved")
func test_relayoutParentChildTrees_keepsRootAnchor() throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")

    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 140, y: 260, width: 220, height: 120)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 360, y: 120, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ]
    )

    let result = CanvasTreeLayoutService.relayoutParentChildTrees(in: graph)

    let root = try #require(result[rootID])
    #expect(root.x == 140)
    #expect(root.y == 260)
}

private struct SymmetricLayoutFixture {
    let rootID: CanvasNodeID
    let childAID: CanvasNodeID
    let childBID: CanvasNodeID
    let childCID: CanvasNodeID
    let graph: CanvasGraph
}

private func makeSymmetricLayoutFixture() -> SymmetricLayoutFixture {
    let rootID = CanvasNodeID(rawValue: "root")
    let childAID = CanvasNodeID(rawValue: "child-a")
    let childBID = CanvasNodeID(rawValue: "child-b")
    let childCID = CanvasNodeID(rawValue: "child-c")

    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 220, height: 100)
            ),
            childAID: CanvasNode(
                id: childAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 380, y: 60, width: 220, height: 40)
            ),
            childBID: CanvasNode(
                id: childBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 380, y: 200, width: 220, height: 80)
            ),
            childCID: CanvasNode(
                id: childCID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 380, y: 320, width: 220, height: 40)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-a"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-a"),
                fromNodeID: rootID,
                toNodeID: childAID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-b"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-b"),
                fromNodeID: rootID,
                toNodeID: childBID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-c"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-c"),
                fromNodeID: rootID,
                toNodeID: childCID,
                relationType: .parentChild
            ),
        ]
    )

    return SymmetricLayoutFixture(
        rootID: rootID,
        childAID: childAID,
        childBID: childBID,
        childCID: childCID,
        graph: graph
    )
}
