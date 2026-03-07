import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasView connect selection: initial target chooses nearest node by physical position")
func test_initialConnectNodeSelectionTargetID_choosesNearestNode() {
    let sourceNode = CanvasNode(
        id: CanvasNodeID(rawValue: "source"),
        kind: .text,
        text: "source",
        bounds: CanvasBounds(x: 100, y: 100, width: 120, height: 80)
    )
    let farSortedFirstNode = CanvasNode(
        id: CanvasNodeID(rawValue: "far-sorted-first"),
        kind: .text,
        text: "far",
        bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 80)
    )
    let nearestNode = CanvasNode(
        id: CanvasNodeID(rawValue: "nearest"),
        kind: .text,
        text: "near",
        bounds: CanvasBounds(x: 240, y: 110, width: 120, height: 80)
    )

    let targetID = CanvasView.initialConnectNodeSelectionTargetID(
        sourceNode: sourceNode,
        candidates: [farSortedFirstNode, nearestNode]
    )

    #expect(targetID == nearestNode.id)
}

@Test("CanvasView connect selection: initial target breaks equal distance ties by position then id")
func test_initialConnectNodeSelectionTargetID_breaksEqualDistanceTiesDeterministically() {
    let sourceNode = CanvasNode(
        id: CanvasNodeID(rawValue: "source"),
        kind: .text,
        text: "source",
        bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
    )
    let lowerNode = CanvasNode(
        id: CanvasNodeID(rawValue: "lower"),
        kind: .text,
        text: "lower",
        bounds: CanvasBounds(x: 100, y: 200, width: 100, height: 100)
    )
    let upperNode = CanvasNode(
        id: CanvasNodeID(rawValue: "upper"),
        kind: .text,
        text: "upper",
        bounds: CanvasBounds(x: 100, y: 0, width: 100, height: 100)
    )

    let targetID = CanvasView.initialConnectNodeSelectionTargetID(
        sourceNode: sourceNode,
        candidates: [lowerNode, upperNode]
    )

    #expect(targetID == upperNode.id)
}
