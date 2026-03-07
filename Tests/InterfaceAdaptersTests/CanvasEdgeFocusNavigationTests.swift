// Background: Edge focus navigation should follow rendered edge positions instead of endpoint bundles.
// Responsibility: Verify UI-side edge focus navigation uses rendered geometry for directional movement.
import Domain
import SwiftUI
import Testing

@testable import InterfaceAdapters

@Test("CanvasEdgeFocusNavigation: right movement escapes duplicated bundle and follows rendered edge positions")
func test_nextFocusedEdgeID_rightMovement_escapesDuplicatedBundle() throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let nodeDID = CanvasNodeID(rawValue: "node-d")
    let edge1ID = CanvasEdgeID(rawValue: "edge-1")
    let edge2ID = CanvasEdgeID(rawValue: "edge-2")
    let edge3ID = CanvasEdgeID(rawValue: "edge-3")

    let nodesByID: [CanvasNodeID: CanvasNode] = [
        nodeAID: makeNode(id: nodeAID, x: 0, y: 120, width: 220, height: 220),
        nodeBID: makeNode(id: nodeBID, x: 360, y: 120, width: 220, height: 220),
        nodeCID: makeNode(id: nodeCID, x: 760, y: 120, width: 220, height: 220),
        nodeDID: makeNode(id: nodeDID, x: 1120, y: 120, width: 220, height: 220),
    ]
    let edges = [
        CanvasEdge(id: edge1ID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
        CanvasEdge(id: edge2ID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
        CanvasEdge(id: edge3ID, fromNodeID: nodeCID, toNodeID: nodeDID, relationType: .normal),
    ]
    let branchCoordinateByParentAndDirection = CanvasEdgeRouting.branchCoordinateByParentAndDirection(
        edges: edges,
        nodesByID: nodesByID
    )
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: edges,
        nodesByID: nodesByID
    )
    let context = makeContext(
        edges: edges,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
        laneOffsetsByEdgeID: laneOffsetsByEdgeID,
        edgeIDs: [edge1ID, edge2ID, edge3ID]
    )

    let nextFocusedEdgeID = CanvasEdgeFocusNavigation.nextFocusedEdgeID(
        in: context,
        currentEdgeID: edge1ID,
        direction: .right
    )

    #expect(nextFocusedEdgeID == edge3ID)
}

@Test("CanvasEdgeFocusNavigation: downward movement can choose visually lower duplicated edge")
func test_nextFocusedEdgeID_downMovement_canChooseLowerDuplicatedEdge() throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let edge1ID = CanvasEdgeID(rawValue: "edge-1")
    let edge2ID = CanvasEdgeID(rawValue: "edge-2")

    let nodesByID: [CanvasNodeID: CanvasNode] = [
        nodeAID: makeNode(id: nodeAID, x: 80, y: 120, width: 220, height: 220),
        nodeBID: makeNode(id: nodeBID, x: 480, y: 360, width: 220, height: 220),
    ]
    let edges = [
        CanvasEdge(id: edge1ID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
        CanvasEdge(id: edge2ID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
    ]
    let branchCoordinateByParentAndDirection = CanvasEdgeRouting.branchCoordinateByParentAndDirection(
        edges: edges,
        nodesByID: nodesByID
    )
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: edges,
        nodesByID: nodesByID
    )
    let context = makeContext(
        edges: edges,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
        laneOffsetsByEdgeID: laneOffsetsByEdgeID,
        edgeIDs: [edge1ID, edge2ID]
    )

    let focusPointsByEdgeID = try focusPoints(
        edges: edges,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
        laneOffsetsByEdgeID: laneOffsetsByEdgeID
    )
    let topEdgeID = try edgeID(atVisualTopIn: focusPointsByEdgeID)
    let bottomEdgeID = try edgeID(atVisualBottomIn: focusPointsByEdgeID)

    let nextFocusedEdgeID = CanvasEdgeFocusNavigation.nextFocusedEdgeID(
        in: context,
        currentEdgeID: topEdgeID,
        direction: .down
    )

    #expect(nextFocusedEdgeID == bottomEdgeID)
}

@Test("CanvasEdgeFocusNavigation: straight horizontal edges remain navigable when bounding rect height is zero")
func test_nextFocusedEdgeID_straightHorizontalEdgesRemainNavigable() {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let nodeDID = CanvasNodeID(rawValue: "node-d")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let edgeCDID = CanvasEdgeID(rawValue: "edge-c-d")

    let nodesByID: [CanvasNodeID: CanvasNode] = [
        nodeAID: makeNode(id: nodeAID, x: 0, y: 0, width: 120, height: 120),
        nodeBID: makeNode(id: nodeBID, x: 240, y: 0, width: 120, height: 120),
        nodeCID: makeNode(id: nodeCID, x: 520, y: 0, width: 120, height: 120),
        nodeDID: makeNode(id: nodeDID, x: 760, y: 0, width: 120, height: 120),
    ]
    let edges = [
        CanvasEdge(id: edgeABID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
        CanvasEdge(id: edgeCDID, fromNodeID: nodeCID, toNodeID: nodeDID, relationType: .normal),
    ]
    let context = makeContext(
        edges: edges,
        nodesByID: nodesByID,
        edgeShapeStyle: .straight
    )

    let nextFocusedEdgeID = CanvasEdgeFocusNavigation.nextFocusedEdgeID(
        in: context,
        currentEdgeID: edgeABID,
        direction: .right
    )

    #expect(nextFocusedEdgeID == edgeCDID)
}

@Test("CanvasEdgeFocusNavigation: straight vertical edges remain navigable when bounding rect width is zero")
func test_nextFocusedEdgeID_straightVerticalEdgesRemainNavigable() {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let nodeDID = CanvasNodeID(rawValue: "node-d")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let edgeCDID = CanvasEdgeID(rawValue: "edge-c-d")

    let nodesByID: [CanvasNodeID: CanvasNode] = [
        nodeAID: makeNode(id: nodeAID, x: 0, y: 0, width: 120, height: 120),
        nodeBID: makeNode(id: nodeBID, x: 0, y: 240, width: 120, height: 120),
        nodeCID: makeNode(id: nodeCID, x: 0, y: 520, width: 120, height: 120),
        nodeDID: makeNode(id: nodeDID, x: 0, y: 760, width: 120, height: 120),
    ]
    let edges = [
        CanvasEdge(id: edgeABID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
        CanvasEdge(id: edgeCDID, fromNodeID: nodeCID, toNodeID: nodeDID, relationType: .normal),
    ]
    let context = makeContext(
        edges: edges,
        nodesByID: nodesByID,
        edgeShapeStyle: .straight
    )

    let nextFocusedEdgeID = CanvasEdgeFocusNavigation.nextFocusedEdgeID(
        in: context,
        currentEdgeID: edgeABID,
        direction: .down
    )

    #expect(nextFocusedEdgeID == edgeCDID)
}

private func makeNode(
    id: CanvasNodeID,
    x: Double,
    y: Double,
    width: Double,
    height: Double
) -> CanvasNode {
    CanvasNode(
        id: id,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: x, y: y, width: width, height: height)
    )
}

private func makeContext(
    edges: [CanvasEdge],
    nodesByID: [CanvasNodeID: CanvasNode],
    branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double],
    laneOffsetsByEdgeID: [CanvasEdgeID: CanvasEdgeRouting.EdgeLaneOffsets],
    edgeIDs: [CanvasEdgeID],
    edgeShapeStyle: CanvasAreaEdgeShapeStyle = .curved
) -> CanvasEdgeFocusNavigation.Context {
    CanvasEdgeFocusNavigation.Context(
        edges: edges,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
        laneOffsetsByEdgeID: laneOffsetsByEdgeID,
        edgeShapeStyleByEdgeID: Dictionary(uniqueKeysWithValues: edgeIDs.map { ($0, edgeShapeStyle) })
    )
}

private func makeContext(
    edges: [CanvasEdge],
    nodesByID: [CanvasNodeID: CanvasNode],
    edgeShapeStyle: CanvasAreaEdgeShapeStyle
) -> CanvasEdgeFocusNavigation.Context {
    let branchCoordinateByParentAndDirection = CanvasEdgeRouting.branchCoordinateByParentAndDirection(
        edges: edges,
        nodesByID: nodesByID
    )
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: edges,
        nodesByID: nodesByID
    )
    return makeContext(
        edges: edges,
        nodesByID: nodesByID,
        branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
        laneOffsetsByEdgeID: laneOffsetsByEdgeID,
        edgeIDs: edges.map(\.id),
        edgeShapeStyle: edgeShapeStyle
    )
}

private func focusPoints(
    edges: [CanvasEdge],
    nodesByID: [CanvasNodeID: CanvasNode],
    branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double],
    laneOffsetsByEdgeID: [CanvasEdgeID: CanvasEdgeRouting.EdgeLaneOffsets]
) throws -> [CanvasEdgeID: CGPoint] {
    try Dictionary(
        uniqueKeysWithValues: edges.map { edge in
            let path = try #require(
                CanvasEdgeRouting.path(
                    for: edge,
                    nodesByID: nodesByID,
                    branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
                    laneOffsetsByEdgeID: laneOffsetsByEdgeID,
                    edgeShapeStyle: .curved
                )
            )
            let rect = path.boundingRect
            return (edge.id, CGPoint(x: rect.midX, y: rect.midY))
        }
    )
}

private func edgeID(atVisualTopIn focusPointsByEdgeID: [CanvasEdgeID: CGPoint]) throws -> CanvasEdgeID {
    try #require(
        focusPointsByEdgeID.min { lhs, rhs in
            if lhs.value.y != rhs.value.y {
                return lhs.value.y < rhs.value.y
            }
            return lhs.key.rawValue < rhs.key.rawValue
        }?.key
    )
}

private func edgeID(atVisualBottomIn focusPointsByEdgeID: [CanvasEdgeID: CGPoint]) throws -> CanvasEdgeID {
    try #require(
        focusPointsByEdgeID.max { lhs, rhs in
            if lhs.value.y != rhs.value.y {
                return lhs.value.y < rhs.value.y
            }
            return lhs.key.rawValue < rhs.key.rawValue
        }?.key
    )
}
