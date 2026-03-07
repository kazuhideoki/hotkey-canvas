import CoreGraphics
import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasEdgeRouting: curved label anchor follows rendered curve instead of straight midpoint")
func test_labelAnchor_curvedEdge_usesRenderedCurveMidpoint() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeID = CanvasEdgeID(rawValue: "edge-1")
    let edge = CanvasEdge(id: edgeID, fromNodeID: parentID, toNodeID: childID)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLabelAnchorNode(id: parentID, x: 80, y: 200, width: 220, height: 56),
        makeLabelAnchorNode(id: childID, x: 460, y: 360, width: 220, height: 56),
    ])

    let anchor = try #require(
        CanvasEdgeRouting.labelAnchor(
            for: edge,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            edgeShapeStyle: .curved
        )
    )

    let straightMidpoint = CGPoint(x: 380, y: 308)
    #expect(anchor.point != straightMidpoint)
}

@Test("CanvasEdgeRouting: duplicated edges receive distinct label anchors on their own rendered paths")
func test_labelAnchor_duplicatedEdges_returnsSeparatedAnchors() throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeAID = CanvasEdgeID(rawValue: "edge-a")
    let edgeBID = CanvasEdgeID(rawValue: "edge-b")
    let edgeA = CanvasEdge(id: edgeAID, fromNodeID: parentID, toNodeID: childID, relationType: .normal)
    let edgeB = CanvasEdge(id: edgeBID, fromNodeID: parentID, toNodeID: childID, relationType: .normal)
    let nodesByID = Dictionary(uniqueKeysWithValues: [
        makeLabelAnchorNode(id: parentID, x: 80, y: 200, width: 220, height: 220),
        makeLabelAnchorNode(id: childID, x: 460, y: 360, width: 220, height: 220),
    ])
    let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
        edges: [edgeA, edgeB],
        nodesByID: nodesByID
    )

    let anchorA = try #require(
        CanvasEdgeRouting.labelAnchor(
            for: edgeA,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID,
            edgeShapeStyle: .curved
        )
    )
    let anchorB = try #require(
        CanvasEdgeRouting.labelAnchor(
            for: edgeB,
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: [:],
            laneOffsetsByEdgeID: laneOffsetsByEdgeID,
            edgeShapeStyle: .curved
        )
    )

    #expect(anchorA.point != anchorB.point)
}

private func makeLabelAnchorNode(
    id: CanvasNodeID,
    x: Double,
    y: Double,
    width: Double,
    height: Double
) -> (CanvasNodeID, CanvasNode) {
    (
        id,
        CanvasNode(
            id: id,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: x, y: y, width: width, height: height)
        )
    )
}
