import Application
import Domain
import Testing

// Background: Ordering-specific sibling insertion scenarios are independent from core sibling creation behavior.
// Responsibility: Verify deterministic sibling ordering when Y coordinates are equal.
@Test("ApplyCanvasCommandsUseCase: addSiblingNode below keeps ordering when next sibling shares Y")
func test_apply_addSiblingNodeBelow_withEqualY_keepsNewNodeBelowFocused() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let nextID = CanvasNodeID(rawValue: "next")

    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 120, y: 200, width: 220, height: 120)
            ),
            nextID: CanvasNode(
                id: nextID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 200, width: 220, height: 120)
            )
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-focused"),
                fromNodeID: rootID,
                toNodeID: focusedID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-root-next"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-next"),
                fromNodeID: rootID,
                toNodeID: nextID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addSiblingNode(position: .below)])

    let newSiblingID = try #require(result.newState.focusedNodeID)
    let children = result.newState.edgesByID.values
        .filter { $0.relationType == .parentChild && $0.fromNodeID == rootID }
        .compactMap { result.newState.nodesByID[$0.toNodeID] }
        .sorted {
            if $0.bounds.y == $1.bounds.y {
                if $0.bounds.x == $1.bounds.x {
                    return $0.id.rawValue < $1.id.rawValue
                }
                return $0.bounds.x < $1.bounds.x
            }
            return $0.bounds.y < $1.bounds.y
        }
    let newIndex = try #require(children.firstIndex(where: { $0.id == newSiblingID }))
    let focusedIndex = try #require(children.firstIndex(where: { $0.id == focusedID }))
    #expect(newIndex > focusedIndex)
}

func addSiblingTestEnclosingBounds(of nodes: [CanvasNode]) -> CanvasBounds {
    guard let first = nodes.first else {
        return CanvasBounds(x: 0, y: 0, width: 0, height: 0)
    }

    var minX = first.bounds.x
    var minY = first.bounds.y
    var maxX = first.bounds.x + first.bounds.width
    var maxY = first.bounds.y + first.bounds.height

    for node in nodes.dropFirst() {
        minX = min(minX, node.bounds.x)
        minY = min(minY, node.bounds.y)
        maxX = max(maxX, node.bounds.x + node.bounds.width)
        maxY = max(maxY, node.bounds.y + node.bounds.height)
    }

    return CanvasBounds(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

func addSiblingTestBoundsOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds, spacing: Double = 0) -> Bool {
    let halfSpacing = max(0, spacing) / 2
    let lhsLeft = lhs.x - halfSpacing
    let lhsTop = lhs.y - halfSpacing
    let lhsRight = lhs.x + lhs.width + halfSpacing
    let lhsBottom = lhs.y + lhs.height + halfSpacing
    let rhsLeft = rhs.x - halfSpacing
    let rhsTop = rhs.y - halfSpacing
    let rhsRight = rhs.x + rhs.width + halfSpacing
    let rhsBottom = rhs.y + rhs.height + halfSpacing

    return lhsLeft < rhsRight
        && lhsRight > rhsLeft
        && lhsTop < rhsBottom
        && lhsBottom > rhsTop
}
