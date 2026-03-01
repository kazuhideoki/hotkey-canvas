// Background: Focus target can be larger than the viewport, especially in area target mode.
// Responsibility: Keep the focused shape visible by camera compensation and conditional auto zoom-out.
import Domain
import SwiftUI

extension CanvasView {
    func cameraOffset(viewportSize: CGSize) -> CGSize {
        let nodes = viewModel.nodes.map(displayNodeForCurrentEditingState)
        guard !nodes.isEmpty, let focusNode = currentFocusNode(in: nodes) else {
            return .zero
        }
        let anchorPoint = hasInitializedCameraAnchor ? cameraAnchorPoint : centerPoint(for: focusNode)
        return CGSize(
            width: (viewportSize.width / 2) - anchorPoint.x,
            height: (viewportSize.height / 2) - anchorPoint.y
        )
    }

    func applyFocusVisibilityRule(viewportSize: CGSize) {
        applyFocusVisibilityRule(viewportSize: viewportSize, allowZoomOutToFitFocusedShape: true)
    }

    func applyFocusVisibilityRule(
        viewportSize: CGSize,
        allowZoomOutToFitFocusedShape: Bool
    ) {
        let nodes = viewModel.nodes.map(displayNodeForCurrentEditingState)
        guard !nodes.isEmpty else {
            hasInitializedCameraAnchor = false
            cameraAnchorPoint = .zero
            manualPanOffset = .zero
            return
        }
        guard let focusRect = focusedShapeRect(in: nodes) else {
            return
        }

        if !hasInitializedCameraAnchor {
            cameraAnchorPoint = CGPoint(x: focusRect.midX, y: focusRect.midY)
            hasInitializedCameraAnchor = true
            manualPanOffset = .zero
        }

        if allowZoomOutToFitFocusedShape {
            let fittedZoomScale = CanvasViewportPanPolicy.zoomScaleToFit(
                focusRect: focusRect,
                viewportSize: viewportSize,
                currentZoomScale: zoomScale,
                minimumZoomScale: Self.zoomScales.last ?? zoomScale
            )
            if fittedZoomScale < zoomScale {
                zoomScale = fittedZoomScale
            }
        }

        updateCameraAnchorToKeepFocusedShapeVisible(
            focusRect: focusRect,
            viewportSize: viewportSize
        )
    }

    func updateCameraAnchorToKeepFocusedShapeVisible(
        focusRect: CGRect,
        viewportSize: CGSize
    ) {
        let autoCenterOffset = cameraOffset(viewportSize: viewportSize)
        let scaledAutoCenterOffset = CGSize(
            width: autoCenterOffset.width * zoomScale,
            height: autoCenterOffset.height * zoomScale
        )
        let effectiveOffset = CanvasViewportPanPolicy.combinedOffset(
            autoCenterOffset: scaledAutoCenterOffset,
            manualPanOffset: manualPanOffset,
            activeDragOffset: .zero
        )
        let visibleFocusRect = CanvasViewportTransform.rectOnScreen(
            worldRect: focusRect,
            viewportSize: viewportSize,
            zoomScale: zoomScale,
            effectiveOffset: effectiveOffset
        )
        let compensation = CanvasViewportPanPolicy.overflowCompensation(
            focusRect: visibleFocusRect,
            viewportSize: viewportSize,
            effectiveOffset: .zero
        )
        guard compensation != .zero else {
            return
        }

        let nextScaledAutoCenterOffset = CGSize(
            width: scaledAutoCenterOffset.width + compensation.width,
            height: scaledAutoCenterOffset.height + compensation.height
        )
        let nextAutoCenterOffset = CGSize(
            width: nextScaledAutoCenterOffset.width / zoomScale,
            height: nextScaledAutoCenterOffset.height / zoomScale
        )
        cameraAnchorPoint = CGPoint(
            x: (viewportSize.width / 2) - nextAutoCenterOffset.width,
            y: (viewportSize.height / 2) - nextAutoCenterOffset.height
        )
    }

    func focusedShapeRect(in nodes: [CanvasNode]) -> CGRect? {
        if operationTargetKind == .area, let focusedAreaRect = focusedAreaRect(in: nodes) {
            return focusedAreaRect
        }
        guard let focusNode = currentFocusNode(in: nodes) else {
            return nil
        }
        return focusRect(for: focusNode)
    }

    func focusedAreaRect(in nodes: [CanvasNode]) -> CGRect? {
        guard let focusedAreaID = viewModel.focusedAreaID else {
            return nil
        }
        let areaNodes = nodes.filter { viewModel.areaIDByNodeID[$0.id] == focusedAreaID }
        let areaNodeIDs = Set(areaNodes.map(\.id))
        guard !areaNodeIDs.isEmpty else {
            return nil
        }
        let graph = CanvasGraph(nodesByID: Dictionary(uniqueKeysWithValues: areaNodes.map { ($0.id, $0) }))
        guard
            let outline = CanvasAreaLayoutService.makeAreaOutline(
                nodeIDs: areaNodeIDs,
                in: graph,
                shapeKind: .convexHull
            )
        else {
            return nil
        }
        let padding = Self.areaFocusOutlinePadding
        return CGRect(
            x: outline.bounds.minX - padding,
            y: outline.bounds.minY - padding,
            width: outline.bounds.width + (padding * 2),
            height: outline.bounds.height + (padding * 2)
        )
    }

    func currentFocusNode(in nodes: [CanvasNode]) -> CanvasNode? {
        if let focusedNodeID = viewModel.focusedNodeID {
            return nodes.first(where: { $0.id == focusedNodeID }) ?? nodes.first
        }
        return nodes.first
    }

    func focusRect(for node: CanvasNode) -> CGRect {
        CGRect(
            x: node.bounds.x,
            y: node.bounds.y,
            width: node.bounds.width,
            height: node.bounds.height
        )
    }

    func focusRectOnScreen(
        for node: CanvasNode,
        viewportSize: CGSize,
        effectiveOffset: CGSize
    ) -> CGRect {
        CanvasViewportTransform.rectOnScreen(
            worldRect: focusRect(for: node),
            viewportSize: viewportSize,
            zoomScale: zoomScale,
            effectiveOffset: effectiveOffset
        )
    }
}
