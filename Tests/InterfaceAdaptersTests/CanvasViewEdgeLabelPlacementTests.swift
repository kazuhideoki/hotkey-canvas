import CoreGraphics
import Domain
import Testing

@testable import InterfaceAdapters

@Test("エッジ接線に沿って広がる同じバンドルのラベル")
func test_resolveEdgeLabelPlacements_sameBundle_spreadsAlongTangent() {
    let firstEdgeID = CanvasEdgeID(rawValue: "edge-1")
    let secondEdgeID = CanvasEdgeID(rawValue: "edge-2")
    let candidates = [
        CanvasView.EdgeLabelPlacementCandidate(
            edgeID: firstEdgeID,
            baseCenter: CGPoint(x: 240, y: 180),
            tangent: CGVector(dx: 1, dy: 0),
            normal: CGVector(dx: 0, dy: -1),
            size: CGSize(width: 80, height: 24),
            bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
            bundleSortValue: -1,
            tangentOffsetLimit: .greatestFiniteMagnitude
        ),
        CanvasView.EdgeLabelPlacementCandidate(
            edgeID: secondEdgeID,
            baseCenter: CGPoint(x: 240, y: 180),
            tangent: CGVector(dx: 1, dy: 0),
            normal: CGVector(dx: 0, dy: -1),
            size: CGSize(width: 80, height: 24),
            bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
            bundleSortValue: 1,
            tangentOffsetLimit: .greatestFiniteMagnitude
        ),
    ]

    let placements = CanvasView.resolveEdgeLabelPlacements(candidates: candidates)

    #expect(placements[firstEdgeID] == CGPoint(x: 196, y: 180))
    #expect(placements[secondEdgeID] == CGPoint(x: 284, y: 180))
}

@Test("同じバンドルのラベルも垂直接線に沿って広がります")
func test_resolveEdgeLabelPlacements_sameBundle_verticalTangent_spreadsAlongTangent() {
    let firstEdgeID = CanvasEdgeID(rawValue: "edge-1")
    let secondEdgeID = CanvasEdgeID(rawValue: "edge-2")
    let candidates = [
        CanvasView.EdgeLabelPlacementCandidate(
            edgeID: firstEdgeID,
            baseCenter: CGPoint(x: 240, y: 180),
            tangent: CGVector(dx: 0, dy: 1),
            normal: CGVector(dx: -1, dy: 0),
            size: CGSize(width: 80, height: 24),
            bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
            bundleSortValue: -1,
            tangentOffsetLimit: .greatestFiniteMagnitude
        ),
        CanvasView.EdgeLabelPlacementCandidate(
            edgeID: secondEdgeID,
            baseCenter: CGPoint(x: 240, y: 180),
            tangent: CGVector(dx: 0, dy: 1),
            normal: CGVector(dx: -1, dy: 0),
            size: CGSize(width: 80, height: 24),
            bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
            bundleSortValue: 1,
            tangentOffsetLimit: .greatestFiniteMagnitude
        ),
    ]

    let placements = CanvasView.resolveEdgeLabelPlacements(candidates: candidates)

    #expect(placements[firstEdgeID] == CGPoint(x: 240, y: 136))
    #expect(placements[secondEdgeID] == CGPoint(x: 240, y: 224))
}

@Test("3 つの同じバンドルのラベルは、中央のラベルをアンカー上に維持する")
func test_resolveEdgeLabelPlacements_threeSameBundle_keepsMiddleOnAnchor() {
    let firstEdgeID = CanvasEdgeID(rawValue: "edge-1")
    let secondEdgeID = CanvasEdgeID(rawValue: "edge-2")
    let thirdEdgeID = CanvasEdgeID(rawValue: "edge-3")
    let candidates = [
        CanvasView.EdgeLabelPlacementCandidate(
            edgeID: firstEdgeID,
            baseCenter: CGPoint(x: 240, y: 180),
            tangent: CGVector(dx: 1, dy: 0),
            normal: CGVector(dx: 0, dy: -1),
            size: CGSize(width: 80, height: 24),
            bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
            bundleSortValue: -1,
            tangentOffsetLimit: .greatestFiniteMagnitude
        ),
        CanvasView.EdgeLabelPlacementCandidate(
            edgeID: secondEdgeID,
            baseCenter: CGPoint(x: 240, y: 180),
            tangent: CGVector(dx: 1, dy: 0),
            normal: CGVector(dx: 0, dy: -1),
            size: CGSize(width: 80, height: 24),
            bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
            bundleSortValue: 0,
            tangentOffsetLimit: .greatestFiniteMagnitude
        ),
        CanvasView.EdgeLabelPlacementCandidate(
            edgeID: thirdEdgeID,
            baseCenter: CGPoint(x: 240, y: 180),
            tangent: CGVector(dx: 1, dy: 0),
            normal: CGVector(dx: 0, dy: -1),
            size: CGSize(width: 80, height: 24),
            bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
            bundleSortValue: 1,
            tangentOffsetLimit: .greatestFiniteMagnitude
        ),
    ]

    let placements = CanvasView.resolveEdgeLabelPlacements(candidates: candidates)

    #expect(placements[firstEdgeID] == CGPoint(x: 152, y: 180))
    #expect(placements[secondEdgeID] == CGPoint(x: 240, y: 180))
    #expect(placements[thirdEdgeID] == CGPoint(x: 328, y: 180))
}

@Test("ラベルの幅が混在しても、すべてのラベルが最長の幅に従うように強制されるわけではない")
func test_resolveEdgeLabelPlacements_mixedWidths_usesNeighborAwareSpacing() {
    let shortEdgeID = CanvasEdgeID(rawValue: "edge-short")
    let longEdgeID = CanvasEdgeID(rawValue: "edge-long")
    let candidates = [
        CanvasView.EdgeLabelPlacementCandidate(
            edgeID: shortEdgeID,
            baseCenter: CGPoint(x: 240, y: 180),
            tangent: CGVector(dx: 1, dy: 0),
            normal: CGVector(dx: 0, dy: -1),
            size: CGSize(width: 40, height: 24),
            bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
            bundleSortValue: -1,
            tangentOffsetLimit: .greatestFiniteMagnitude
        ),
        CanvasView.EdgeLabelPlacementCandidate(
            edgeID: longEdgeID,
            baseCenter: CGPoint(x: 240, y: 180),
            tangent: CGVector(dx: 1, dy: 0),
            normal: CGVector(dx: 0, dy: -1),
            size: CGSize(width: 200, height: 24),
            bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
            bundleSortValue: 1,
            tangentOffsetLimit: .greatestFiniteMagnitude
        ),
    ]

    let placements = CanvasView.resolveEdgeLabelPlacements(candidates: candidates)

    #expect(placements[shortEdgeID] == CGPoint(x: 176, y: 180))
    #expect(placements[longEdgeID] == CGPoint(x: 304, y: 180))
}

@Test("候補の順序は解決された中心に影響を与えない")
func test_resolveEdgeLabelPlacements_isStableAcrossCandidateOrder() {
    let firstEdgeID = CanvasEdgeID(rawValue: "edge-1")
    let secondEdgeID = CanvasEdgeID(rawValue: "edge-2")
    let thirdEdgeID = CanvasEdgeID(rawValue: "edge-3")
    let first = CanvasView.EdgeLabelPlacementCandidate(
        edgeID: firstEdgeID,
        baseCenter: CGPoint(x: 240, y: 180),
        tangent: CGVector(dx: 1, dy: 0),
        normal: CGVector(dx: 0, dy: -1),
        size: CGSize(width: 80, height: 24),
        bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
        bundleSortValue: -1,
        tangentOffsetLimit: .greatestFiniteMagnitude
    )
    let second = CanvasView.EdgeLabelPlacementCandidate(
        edgeID: secondEdgeID,
        baseCenter: CGPoint(x: 240, y: 180),
        tangent: CGVector(dx: 1, dy: 0),
        normal: CGVector(dx: 0, dy: -1),
        size: CGSize(width: 80, height: 24),
        bundleKey: .init(firstNodeID: "c", secondNodeID: "d"),
        bundleSortValue: 0,
        tangentOffsetLimit: .greatestFiniteMagnitude
    )
    let third = CanvasView.EdgeLabelPlacementCandidate(
        edgeID: thirdEdgeID,
        baseCenter: CGPoint(x: 240, y: 180),
        tangent: CGVector(dx: 1, dy: 0),
        normal: CGVector(dx: 0, dy: -1),
        size: CGSize(width: 80, height: 24),
        bundleKey: .init(firstNodeID: "a", secondNodeID: "b"),
        bundleSortValue: 1,
        tangentOffsetLimit: .greatestFiniteMagnitude
    )

    let forwardPlacements = CanvasView.resolveEdgeLabelPlacements(candidates: [first, second, third])
    let reversedPlacements = CanvasView.resolveEdgeLabelPlacements(candidates: [third, second, first])

    #expect(forwardPlacements == reversedPlacements)
}
