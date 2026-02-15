import Application
import Domain
import Testing

// Background: Child-node creation grows explicit parent-child structure from focused nodes.
// Responsibility: Verify child creation, edge connection, and horizontal overlap handling.
@Test("ApplyCanvasCommandsUseCase: addChildNode creates child and parent-child edge")
func test_apply_addChildNode_createsChildAndEdge() async throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let parent = CanvasNode(
        id: parentID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 100, y: 100, width: 220, height: 120)
    )
    let graph = CanvasGraph(
        nodesByID: [parentID: parent],
        edgesByID: [:],
        focusedNodeID: parentID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addChildNode])

    #expect(result.newState.nodesByID.count == 2)
    let childID = try #require(result.newState.focusedNodeID)
    let child = try #require(result.newState.nodesByID[childID])
    #expect(child.id != parentID)
    let edge = try #require(result.newState.edgesByID.values.first)
    #expect(edge.fromNodeID == parentID)
    #expect(edge.toNodeID == childID)
    #expect(edge.relationType == .parentChild)
    #expect(child.bounds.x >= parent.bounds.x + parent.bounds.width)
}

@Test("ApplyCanvasCommandsUseCase: addChildNode resolves overlap by moving areas")
func test_apply_addChildNode_avoidsOverlap() async throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let parent = CanvasNode(
        id: parentID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 100, y: 100, width: 220, height: 120)
    )
    let blocker = CanvasNode(
        id: blockerID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 352, y: 100, width: 220, height: 120)
    )
    let graph = CanvasGraph(
        nodesByID: [parentID: parent, blockerID: blocker],
        edgesByID: [:],
        focusedNodeID: parentID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.addChildNode])

    let childID = try #require(result.newState.focusedNodeID)
    let child = try #require(result.newState.nodesByID[childID])
    let parentAfter = try #require(result.newState.nodesByID[parentID])
    let blockerAfter = try #require(result.newState.nodesByID[blockerID])

    #expect(parentAfter.bounds.x != parent.bounds.x || parentAfter.bounds.y != parent.bounds.y)
    #expect(blockerAfter.bounds.x != blocker.bounds.x || blockerAfter.bounds.y != blocker.bounds.y)
    #expect(child.bounds.x - parentAfter.bounds.x == parent.bounds.width + 32)
    #expect(child.bounds.y == parentAfter.bounds.y)

    let parentAreaBounds = enclosingBounds(of: [parentAfter, child])
    #expect(boundsOverlap(parentAreaBounds, blockerAfter.bounds, spacing: 32) == false)
}

private func enclosingBounds(of nodes: [CanvasNode]) -> CanvasBounds {
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

private func boundsOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds, spacing: Double = 0) -> Bool {
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
