// Background: Canvas rendering should consume one shared world-space snapshot before viewport transform is applied.
// Responsibility: Build animated scene snapshots and derive render helpers from the current shared scene.
import Domain
import SwiftUI

extension CanvasView {
    func makeSceneSnapshot(
        displayNodes: [CanvasNode],
        displayEdges: [CanvasEdge],
        viewportSize: CGSize,
        effectiveOffset: CGSize,
        cameraIntent: CanvasSceneCameraIntent
    ) -> CanvasSceneSnapshot {
        CanvasSceneSnapshot(
            nodes: displayNodes,
            edges: displayEdges,
            areaIDByNodeID: viewModel.areaIDByNodeID,
            areaNodeIDsByAreaID: areaNodeIDsByAreaID(for: displayNodes),
            areaEditingModeByID: viewModel.areaEditingModeByID,
            areaEdgeShapeStyleByID: viewModel.areaEdgeShapeStyleByID,
            viewport: CanvasSceneViewportState(
                viewportSize: viewportSize,
                zoomScale: zoomScale,
                effectiveOffset: effectiveOffset
            ),
            cameraIntent: cameraIntent
        )
    }

    func edgeRenderContext(scene: CanvasSceneSnapshot) -> EdgeRenderContext {
        let nodesByID = scene.nodesByID
        let branchCoordinateByParentAndDirection = CanvasEdgeRouting.branchCoordinateByParentAndDirection(
            edges: scene.edges,
            nodesByID: nodesByID
        )
        let treeBranchCoordinateByParentAndDirection = CanvasEdgeRouting.treeBranchCoordinateByParentAndDirection(
            edges: scene.edges,
            nodesByID: nodesByID
        )
        let laneOffsetsByEdgeID = CanvasEdgeRouting.laneOffsetsByEdgeID(
            edges: scene.edges,
            nodesByID: nodesByID
        )
        return EdgeRenderContext(
            nodesByID: nodesByID,
            branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
            treeBranchCoordinateByParentAndDirection: treeBranchCoordinateByParentAndDirection,
            laneOffsetsByEdgeID: laneOffsetsByEdgeID,
            areaIDByNodeID: scene.areaIDByNodeID,
            areaEditingModeByID: scene.areaEditingModeByID,
            areaEdgeShapeStyleByID: scene.areaEdgeShapeStyleByID
        )
    }

    func viewportTransform(for viewport: CanvasSceneViewportState) -> CGAffineTransform {
        CanvasViewportTransform.affineTransform(
            viewportSize: viewport.viewportSize,
            zoomScale: viewport.zoomScale,
            effectiveOffset: viewport.effectiveOffset
        )
    }

    func renderedNode(
        _ node: CanvasNode,
        viewportTransform: CGAffineTransform
    ) -> CanvasNode {
        let renderedRect = CGRect(
            x: node.bounds.x,
            y: node.bounds.y,
            width: node.bounds.width,
            height: node.bounds.height
        )
        .applying(viewportTransform)
        return CanvasNode(
            id: node.id,
            kind: node.kind,
            text: node.text,
            attachments: node.attachments,
            bounds: CanvasBounds(
                x: renderedRect.origin.x,
                y: renderedRect.origin.y,
                width: renderedRect.width,
                height: renderedRect.height
            ),
            metadata: node.metadata,
            markdownStyleEnabled: node.markdownStyleEnabled
        )
    }

    private func areaNodeIDsByAreaID(for displayNodes: [CanvasNode]) -> [CanvasAreaID: Set<CanvasNodeID>] {
        displayNodes.reduce(into: [:]) { result, node in
            guard let areaID = viewModel.areaIDByNodeID[node.id] else {
                return
            }
            result[areaID, default: []].insert(node.id)
        }
    }
}
