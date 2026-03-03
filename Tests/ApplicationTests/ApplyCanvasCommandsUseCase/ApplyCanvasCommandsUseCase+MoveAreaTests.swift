import Application
import Domain
import Testing

private func boundsOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds) -> Bool {
    lhs.x < rhs.x + rhs.width
        && lhs.x + lhs.width > rhs.x
        && lhs.y < rhs.y + rhs.height
        && lhs.y + lhs.height > rhs.y
}

private func areaBounds(areaID: CanvasAreaID, in graph: CanvasGraph) -> CanvasBounds? {
    guard let area = graph.areasByID[areaID] else {
        return nil
    }
    let nodes = area.nodeIDs.compactMap { graph.nodesByID[$0] }
    guard let first = nodes.first else {
        return nil
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
    return CanvasBounds(
        x: minX,
        y: minY,
        width: maxX - minX,
        height: maxY - minY
    )
}

@Test("ApplyCanvasCommandsUseCase: moveArea translates all nodes in focused area")
func test_apply_moveArea_translatesFocusedAreaNodes() async throws {
    let areaID = CanvasAreaID(rawValue: "focused-area")
    let otherAreaID = CanvasAreaID(rawValue: "other-area")
    let leftID = CanvasNodeID(rawValue: "left")
    let rightID = CanvasNodeID(rawValue: "right")
    let otherID = CanvasNodeID(rawValue: "other")
    let graph = CanvasGraph(
        nodesByID: [
            leftID: CanvasNode(
                id: leftID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 80)
            ),
            rightID: CanvasNode(
                id: rightID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 0, width: 120, height: 80)
            ),
            otherID: CanvasNode(
                id: otherID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 1_200, y: 0, width: 120, height: 80)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: leftID,
        focusedElement: .area(areaID),
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [leftID, rightID], editingMode: .diagram),
            otherAreaID: CanvasArea(id: otherAreaID, nodeIDs: [otherID], editingMode: .diagram),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveArea(.right)])

    let movedLeft = try #require(result.newState.nodesByID[leftID])
    let movedRight = try #require(result.newState.nodesByID[rightID])
    let other = try #require(result.newState.nodesByID[otherID])
    #expect(movedLeft.bounds.x == 220)
    #expect(movedRight.bounds.x == 420)
    #expect(other.bounds.x == 1_200)
}

@Test("ApplyCanvasCommandsUseCase: moveArea resolves overlap with other areas")
func test_apply_moveArea_resolvesAreaOverlap() async throws {
    let movingAreaID = CanvasAreaID(rawValue: "moving-area")
    let blockerAreaID = CanvasAreaID(rawValue: "blocker-area")
    let movingNodeID = CanvasNodeID(rawValue: "moving")
    let blockerNodeID = CanvasNodeID(rawValue: "blocker")
    let graph = CanvasGraph(
        nodesByID: [
            movingNodeID: CanvasNode(
                id: movingNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            ),
            blockerNodeID: CanvasNode(
                id: blockerNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 220, y: 0, width: 220, height: 120)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: movingNodeID,
        focusedElement: .area(movingAreaID),
        areasByID: [
            movingAreaID: CanvasArea(id: movingAreaID, nodeIDs: [movingNodeID], editingMode: .diagram),
            blockerAreaID: CanvasArea(id: blockerAreaID, nodeIDs: [blockerNodeID], editingMode: .diagram),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveArea(.right)])

    let movingAreaBounds = try #require(areaBounds(areaID: movingAreaID, in: result.newState))
    let blockerAreaBounds = try #require(areaBounds(areaID: blockerAreaID, in: result.newState))
    #expect(boundsOverlap(movingAreaBounds, blockerAreaBounds) == false)
}

@Test("ApplyCanvasCommandsUseCase: moveArea supports left direction")
func test_apply_moveArea_supportsLeftDirection() async throws {
    let areaID = CanvasAreaID(rawValue: "focused-area")
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 220, y: 220, width: 120, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        focusedElement: .area(areaID),
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveArea(.left)])

    let movedNode = try #require(result.newState.nodesByID[nodeID])
    #expect(movedNode.bounds.x == 0)
    #expect(movedNode.bounds.y == 220)
}

@Test("ApplyCanvasCommandsUseCase: moveArea supports up direction")
func test_apply_moveArea_supportsUpDirection() async throws {
    let areaID = CanvasAreaID(rawValue: "focused-area")
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 220, y: 220, width: 120, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        focusedElement: .area(areaID),
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveArea(.up)])

    let movedNode = try #require(result.newState.nodesByID[nodeID])
    #expect(movedNode.bounds.x == 220)
    #expect(movedNode.bounds.y == 0)
}

@Test("ApplyCanvasCommandsUseCase: moveArea supports down direction")
func test_apply_moveArea_supportsDownDirection() async throws {
    let areaID = CanvasAreaID(rawValue: "focused-area")
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 220, y: 220, width: 120, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        focusedElement: .area(areaID),
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveArea(.down)])

    let movedNode = try #require(result.newState.nodesByID[nodeID])
    #expect(movedNode.bounds.x == 220)
    #expect(movedNode.bounds.y == 440)
}

@Test("ApplyCanvasCommandsUseCase: moveArea keeps relative positions inside moved area")
func test_apply_moveArea_preservesRelativePositionsWithinArea() async throws {
    let movingAreaID = CanvasAreaID(rawValue: "moving-area")
    let blockerAreaID = CanvasAreaID(rawValue: "blocker-area")
    let firstNodeID = CanvasNodeID(rawValue: "first")
    let secondNodeID = CanvasNodeID(rawValue: "second")
    let blockerNodeID = CanvasNodeID(rawValue: "blocker")
    let graph = CanvasGraph(
        nodesByID: [
            firstNodeID: CanvasNode(
                id: firstNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            secondNodeID: CanvasNode(
                id: secondNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 300, y: 160, width: 120, height: 80)
            ),
            blockerNodeID: CanvasNode(
                id: blockerNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 220, y: 0, width: 220, height: 120)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: firstNodeID,
        focusedElement: .area(movingAreaID),
        areasByID: [
            movingAreaID: CanvasArea(id: movingAreaID, nodeIDs: [firstNodeID, secondNodeID], editingMode: .diagram),
            blockerAreaID: CanvasArea(id: blockerAreaID, nodeIDs: [blockerNodeID], editingMode: .diagram),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)
    let beforeFirstNode = try #require(graph.nodesByID[firstNodeID])
    let beforeSecondNode = try #require(graph.nodesByID[secondNodeID])
    let beforeDeltaX = beforeSecondNode.bounds.x - beforeFirstNode.bounds.x
    let beforeDeltaY = beforeSecondNode.bounds.y - beforeFirstNode.bounds.y

    let result = try await sut.apply(commands: [.moveArea(.right)])

    let afterFirstNode = try #require(result.newState.nodesByID[firstNodeID])
    let afterSecondNode = try #require(result.newState.nodesByID[secondNodeID])
    let afterDeltaX = afterSecondNode.bounds.x - afterFirstNode.bounds.x
    let afterDeltaY = afterSecondNode.bounds.y - afterFirstNode.bounds.y
    #expect(afterDeltaX == beforeDeltaX)
    #expect(afterDeltaY == beforeDeltaY)
}
