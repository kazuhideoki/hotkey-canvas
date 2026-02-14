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

@Test("ApplyCanvasCommandsUseCase: addChildNode avoids overlap by shifting rightward")
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
    #expect(child.bounds.x >= blocker.bounds.x + blocker.bounds.width)
}
