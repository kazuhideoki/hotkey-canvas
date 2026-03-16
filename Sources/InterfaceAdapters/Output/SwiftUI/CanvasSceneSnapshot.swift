// Background: Canvas animation needs one shared intermediate scene so nodes, edges, labels, and outlines move together.
// Responsibility: Represent one world-space render snapshot and provide interpolation for animated transitions.
import Domain
import Foundation

struct CanvasSceneCameraIntent: Equatable {
    let zoomScale: Double
    let manualPanOffset: CGSize
    let hasInitializedCameraAnchor: Bool
    let cameraAnchorPoint: CGPoint
}

struct CanvasSceneViewportState: Equatable {
    let viewportSize: CGSize
    let zoomScale: Double
    let effectiveOffset: CGSize

    static func interpolate(
        from source: CanvasSceneViewportState,
        to target: CanvasSceneViewportState,
        progress: Double
    ) -> CanvasSceneViewportState {
        CanvasSceneViewportState(
            viewportSize: CGSize(
                width: lerp(source.viewportSize.width, target.viewportSize.width, progress),
                height: lerp(source.viewportSize.height, target.viewportSize.height, progress)
            ),
            zoomScale: lerp(source.zoomScale, target.zoomScale, progress),
            effectiveOffset: CGSize(
                width: lerp(source.effectiveOffset.width, target.effectiveOffset.width, progress),
                height: lerp(source.effectiveOffset.height, target.effectiveOffset.height, progress)
            )
        )
    }
}

struct CanvasSceneSnapshot: Equatable {
    let nodes: [CanvasNode]
    let edges: [CanvasEdge]
    let areaIDByNodeID: [CanvasNodeID: CanvasAreaID]
    let areaNodeIDsByAreaID: [CanvasAreaID: Set<CanvasNodeID>]
    let areaEditingModeByID: [CanvasAreaID: CanvasEditingMode]
    let areaEdgeShapeStyleByID: [CanvasAreaID: CanvasAreaEdgeShapeStyle]
    let viewport: CanvasSceneViewportState
    let cameraIntent: CanvasSceneCameraIntent

    var nodesByID: [CanvasNodeID: CanvasNode] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }

    func hasAnimatedDifference(comparedTo other: CanvasSceneSnapshot) -> Bool {
        cameraIntent != other.cameraIntent && hasSameContent(as: other)
    }

    private func hasSameContent(as other: CanvasSceneSnapshot) -> Bool {
        nodes == other.nodes
            && edges == other.edges
            && areaIDByNodeID == other.areaIDByNodeID
            && areaNodeIDsByAreaID == other.areaNodeIDsByAreaID
            && areaEditingModeByID == other.areaEditingModeByID
            && areaEdgeShapeStyleByID == other.areaEdgeShapeStyleByID
    }

    func interpolated(to target: CanvasSceneSnapshot, progress: Double) -> CanvasSceneSnapshot {
        let sourceNodesByID = nodesByID
        let interpolatedNodes = target.nodes.map { targetNode in
            let sourceBounds =
                sourceNodesByID[targetNode.id]?.bounds
                ?? emergenceSourceBounds(
                    for: targetNode,
                    target: target,
                    sourceNodesByID: sourceNodesByID
                )
            return CanvasNode(
                id: targetNode.id,
                kind: targetNode.kind,
                text: targetNode.text,
                attachments: targetNode.attachments,
                bounds: CanvasBounds(
                    x: lerp(sourceBounds.x, targetNode.bounds.x, progress),
                    y: lerp(sourceBounds.y, targetNode.bounds.y, progress),
                    width: lerp(sourceBounds.width, targetNode.bounds.width, progress),
                    height: lerp(sourceBounds.height, targetNode.bounds.height, progress)
                ),
                metadata: targetNode.metadata,
                markdownStyleEnabled: targetNode.markdownStyleEnabled
            )
        }

        return CanvasSceneSnapshot(
            nodes: interpolatedNodes,
            edges: target.edges,
            areaIDByNodeID: target.areaIDByNodeID,
            areaNodeIDsByAreaID: target.areaNodeIDsByAreaID,
            areaEditingModeByID: target.areaEditingModeByID,
            areaEdgeShapeStyleByID: target.areaEdgeShapeStyleByID,
            viewport: CanvasSceneViewportState.interpolate(
                from: viewport,
                to: target.viewport,
                progress: progress
            ),
            cameraIntent: target.cameraIntent
        )
    }

    private func emergenceSourceBounds(
        for targetNode: CanvasNode,
        target: CanvasSceneSnapshot,
        sourceNodesByID: [CanvasNodeID: CanvasNode]
    ) -> CanvasBounds {
        if let anchorBounds = emergenceAnchorBounds(
            for: targetNode.id,
            target: target,
            sourceNodesByID: sourceNodesByID
        ) {
            return collapsedBounds(at: anchorBounds.center)
        }
        return collapsedBounds(at: targetNode.bounds.center)
    }

    private func emergenceAnchorBounds(
        for nodeID: CanvasNodeID,
        target: CanvasSceneSnapshot,
        sourceNodesByID: [CanvasNodeID: CanvasNode]
    ) -> CanvasBounds? {
        let relatedNodeIDs = target.edges.compactMap { edge -> CanvasNodeID? in
            if edge.fromNodeID == nodeID {
                return edge.toNodeID
            }
            if edge.toNodeID == nodeID {
                return edge.fromNodeID
            }
            return nil
        }
        .sorted(by: { $0.rawValue < $1.rawValue })

        for relatedNodeID in relatedNodeIDs {
            guard let relatedNode = sourceNodesByID[relatedNodeID] else {
                continue
            }
            return relatedNode.bounds
        }
        return nil
    }

    private func collapsedBounds(at center: CanvasPoint) -> CanvasBounds {
        CanvasBounds(x: center.x, y: center.y, width: 0, height: 0)
    }
}

private func lerp(_ source: Double, _ target: Double, _ progress: Double) -> Double {
    source + ((target - source) * progress)
}

private func lerp(_ source: CGFloat, _ target: CGFloat, _ progress: Double) -> CGFloat {
    source + ((target - source) * progress)
}

extension CanvasBounds {
    fileprivate var center: CanvasPoint {
        CanvasPoint(
            x: x + (width / 2),
            y: y + (height / 2)
        )
    }
}
