import CoreGraphics
import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasSceneSnapshot: interpolation shares viewport and node intermediate state")
func test_interpolatedScene_sharesViewportAndNodeState() {
    let source = makeSnapshot(
        nodes: [
            makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80),
            makeNode(id: "n2", x: 240, y: 0, width: 120, height: 80),
        ],
        edges: [
            makeEdge(id: "e1", from: "n1", to: "n2")
        ],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )
    let target = makeSnapshot(
        nodes: [
            makeNode(id: "n1", x: 60, y: 120, width: 160, height: 100),
            makeNode(id: "n2", x: 360, y: 180, width: 140, height: 90),
        ],
        edges: [
            makeEdge(id: "e1", from: "n1", to: "n2")
        ],
        viewportSize: CGSize(width: 1200, height: 800),
        zoomScale: 1.5,
        effectiveOffset: CGSize(width: 90, height: -60)
    )

    let interpolated = source.interpolated(to: target, progress: 0.5)

    #expect(interpolated.nodes[0].bounds.x == 30)
    #expect(interpolated.nodes[0].bounds.y == 60)
    #expect(interpolated.nodes[0].bounds.width == 140)
    #expect(interpolated.nodes[1].bounds.height == 85)
    #expect(interpolated.viewport.zoomScale == 1.25)
    #expect(interpolated.viewport.effectiveOffset.width == 45)
    #expect(interpolated.viewport.viewportSize.width == 1050)
}

@Test("CanvasSceneSnapshot: added node emerges from related existing node")
func test_interpolatedScene_addedNode_emergesFromConnectedNodeCenter() throws {
    let source = makeSnapshot(
        nodes: [makeNode(id: "parent", x: 40, y: 80, width: 120, height: 80)],
        edges: [],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )
    let target = makeSnapshot(
        nodes: [
            makeNode(id: "parent", x: 40, y: 80, width: 120, height: 80),
            makeNode(id: "child", x: 280, y: 160, width: 120, height: 80),
        ],
        edges: [makeEdge(id: "edge-parent-child", from: "parent", to: "child")],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )

    let interpolated = source.interpolated(to: target, progress: 0.5)
    let child = try #require(interpolated.nodes.first(where: { $0.id.rawValue == "child" }))

    #expect(child.bounds.x == 190)
    #expect(child.bounds.y == 140)
    #expect(child.bounds.width == 60)
    #expect(child.bounds.height == 40)
}

@Test("CanvasSceneSnapshot: text-only change does not count as animated difference")
func test_hasAnimatedDifference_textOnlyChange_returnsFalse() {
    let source = makeSnapshot(
        nodes: [makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80, text: "before")],
        edges: [],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )
    let target = makeSnapshot(
        nodes: [makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80, text: "after")],
        edges: [],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )

    #expect(source.hasAnimatedDifference(comparedTo: target) == false)
}

@Test("CanvasSceneSnapshot: viewport-only change counts as animated difference")
func test_hasAnimatedDifference_viewportOnlyChange_returnsTrue() {
    let source = makeSnapshot(
        nodes: [makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80)],
        edges: [],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )
    let target = makeSnapshot(
        nodes: [makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80)],
        edges: [],
        viewportSize: CGSize(width: 1200, height: 800),
        zoomScale: 1.25,
        effectiveOffset: CGSize(width: 40, height: -20)
    )

    #expect(source.hasAnimatedDifference(comparedTo: target) == true)
}

@Test("CanvasSceneSnapshot: viewport size-only change does not count as animated difference")
func test_hasAnimatedDifference_viewportSizeOnlyChange_returnsFalse() {
    let source = makeSnapshot(
        nodes: [makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80)],
        edges: [],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: CGSize(width: 40, height: -20),
        manualPanOffset: CGSize(width: 24, height: -12),
        hasInitializedCameraAnchor: true,
        cameraAnchorPoint: CGPoint(x: 320, y: 180)
    )
    let target = makeSnapshot(
        nodes: [makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80)],
        edges: [],
        viewportSize: CGSize(width: 1200, height: 800),
        zoomScale: 1.0,
        effectiveOffset: CGSize(width: 190, height: 80),
        manualPanOffset: CGSize(width: 24, height: -12),
        hasInitializedCameraAnchor: true,
        cameraAnchorPoint: CGPoint(x: 320, y: 180)
    )

    #expect(source.hasAnimatedDifference(comparedTo: target) == false)
}

@Test("CanvasSceneSnapshot: node layout change does not count as animated difference")
func test_hasAnimatedDifference_nodeLayoutChange_returnsFalse() {
    let source = makeSnapshot(
        nodes: [makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80)],
        edges: [],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )
    let target = makeSnapshot(
        nodes: [makeNode(id: "n1", x: 180, y: 60, width: 180, height: 120)],
        edges: [],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )

    #expect(source.hasAnimatedDifference(comparedTo: target) == false)
}

@Test("CanvasSceneSnapshot: data change with viewport change does not animate")
func test_hasAnimatedDifference_viewportAndDataChange_returnsFalse() {
    let source = makeSnapshot(
        nodes: [makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80)],
        edges: [],
        viewportSize: CGSize(width: 900, height: 600),
        zoomScale: 1.0,
        effectiveOffset: .zero
    )
    let target = makeSnapshot(
        nodes: [
            makeNode(id: "n1", x: 0, y: 0, width: 120, height: 80),
            makeNode(id: "n2", x: 240, y: 120, width: 120, height: 80),
        ],
        edges: [makeEdge(id: "e1", from: "n1", to: "n2")],
        viewportSize: CGSize(width: 1200, height: 800),
        zoomScale: 1.25,
        effectiveOffset: CGSize(width: 40, height: -20)
    )

    #expect(source.hasAnimatedDifference(comparedTo: target) == false)
}

private func makeNode(
    id: String,
    x: Double,
    y: Double,
    width: Double,
    height: Double,
    text: String? = nil
) -> CanvasNode {
    CanvasNode(
        id: CanvasNodeID(rawValue: id),
        kind: .text,
        text: text,
        bounds: CanvasBounds(x: x, y: y, width: width, height: height)
    )
}

private func makeSnapshot(
    nodes: [CanvasNode],
    edges: [CanvasEdge],
    viewportSize: CGSize,
    zoomScale: Double,
    effectiveOffset: CGSize,
    manualPanOffset: CGSize = .zero,
    hasInitializedCameraAnchor: Bool = false,
    cameraAnchorPoint: CGPoint = .zero
) -> CanvasSceneSnapshot {
    CanvasSceneSnapshot(
        nodes: nodes,
        edges: edges,
        areaIDByNodeID: [:],
        areaNodeIDsByAreaID: [:],
        areaEditingModeByID: [:],
        areaEdgeShapeStyleByID: [:],
        viewport: CanvasSceneViewportState(
            viewportSize: viewportSize,
            zoomScale: zoomScale,
            effectiveOffset: effectiveOffset
        ),
        cameraIntent: CanvasSceneCameraIntent(
            zoomScale: zoomScale,
            manualPanOffset: manualPanOffset,
            hasInitializedCameraAnchor: hasInitializedCameraAnchor,
            cameraAnchorPoint: cameraAnchorPoint
        )
    )
}

private func makeEdge(
    id: String,
    from fromNodeID: String,
    to toNodeID: String
) -> CanvasEdge {
    CanvasEdge(
        id: CanvasEdgeID(rawValue: id),
        fromNodeID: CanvasNodeID(rawValue: fromNodeID),
        toNodeID: CanvasNodeID(rawValue: toNodeID)
    )
}
