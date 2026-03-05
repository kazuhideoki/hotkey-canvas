// Background: Edge labels need inline editing and lightweight rendering without introducing a rich text mode.
// Responsibility: Render edge labels near the route center and provide keyboard-first editing UI.
import AppKit
import Domain
import SwiftUI

extension CanvasView {
    private static let edgeLabelMinWidth: CGFloat = 40
    private static let edgeLabelMaxWidth: CGFloat = 320
    private static let edgeLabelHorizontalPadding: CGFloat = 6
    private static let edgeLabelVerticalPadding: CGFloat = 3
    private static let edgeLabelCornerRadius: CGFloat = 6

    @ViewBuilder
    func edgeLabelOverlay(
        edge: CanvasEdge,
        context: EdgeRenderContext
    ) -> some View {
        let isEditing = edgeEditingContext?.edgeID == edge.id
        let label = isEditing ? (edgeEditingContext?.label ?? "") : (edge.label ?? "")
        if isEditing || !label.isEmpty {
            if let labelCenter = edgeLabelScreenCenter(edge: edge, context: context) {
                let fieldWidth = edgeLabelWidth(for: label, zoomScale: context.zoomScale)
                if isEditing {
                    NodeTextEditor(
                        text: editingEdgeLabelBinding(for: edge.id),
                        nodeWidth: fieldWidth,
                        zoomScale: context.zoomScale,
                        contentScale: edgeLabelEditorContentScale(zoomScale: context.zoomScale),
                        style: nodeTextStyle,
                        contentAlignment: .topLeading,
                        selectAllOnFirstFocus: false,
                        initialCursorPlacement: edgeEditingContext?.initialCursorPlacement ?? .end,
                        initialTypingEvent: edgeEditingContext?.initialTypingEvent,
                        onLayoutMetricsChange: { metrics in
                            updateEdgeEditingLayout(for: edge.id, metrics: metrics)
                        },
                        onCommit: {
                            commitEdgeEditingIfNeeded()
                        },
                        onCancel: {
                            cancelEdgeEditing()
                        }
                    )
                    .frame(
                        width: fieldWidth,
                        height: CGFloat(
                            edgeEditingContext?.editorHeight ?? edgeLabelEditorHeight(zoomScale: context.zoomScale))
                    )
                    .padding(.horizontal, Self.edgeLabelHorizontalPadding)
                    .padding(.vertical, Self.edgeLabelVerticalPadding)
                    .background(styleColor(.textBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius)
                            .stroke(styleColor(.separator), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius))
                    .position(labelCenter)
                    .zIndex(5)
                } else {
                    Text(label)
                        .font(
                            .system(
                                size: max(11 * CGFloat(context.zoomScale), 9),
                                weight: .medium
                            )
                        )
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: fieldWidth, alignment: .leading)
                        .padding(.horizontal, Self.edgeLabelHorizontalPadding)
                        .padding(.vertical, Self.edgeLabelVerticalPadding)
                        .background(styleColor(.textBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius)
                                .stroke(styleColor(.separator), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius))
                        .position(labelCenter)
                        .zIndex(4)
                }
            }
        } else {
            EmptyView()
        }
    }
}

extension CanvasView {
    private func edgeLabelScreenCenter(
        edge: CanvasEdge,
        context: EdgeRenderContext
    ) -> CGPoint? {
        guard
            let geometry = CanvasEdgeRouting.routeGeometry(
                for: edge,
                nodesByID: context.nodesByID,
                branchCoordinateByParentAndDirection: context.branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: context.laneOffsetsByEdgeID
            )
        else {
            return nil
        }
        let canvasPoint = edgeLabelCenter(for: geometry)
        let transform = CanvasViewportTransform.affineTransform(
            viewportSize: context.viewportSize,
            zoomScale: context.zoomScale,
            effectiveOffset: context.cameraOffset
        )
        return canvasPoint.applying(transform)
    }

    private func edgeLabelCenter(for geometry: CanvasEdgeRouting.RouteGeometry) -> CGPoint {
        switch geometry.axis {
        case .horizontal:
            return CGPoint(
                x: geometry.branchCoordinate,
                y: (geometry.startY + geometry.endY) / 2
            )
        case .vertical:
            return CGPoint(
                x: (geometry.startX + geometry.endX) / 2,
                y: geometry.branchCoordinate
            )
        }
    }

    private func edgeLabelWidth(for label: String, zoomScale: Double) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: edgeLabelFontSize(zoomScale: zoomScale),
            weight: .medium
        )
        let measuredWidth =
            label
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                (String(line) as NSString).size(withAttributes: [.font: font]).width
            }
            .max() ?? 0
        let widthWithPadding = measuredWidth + (Self.edgeLabelHorizontalPadding * 2) + 12
        return min(max(widthWithPadding, Self.edgeLabelMinWidth), Self.edgeLabelMaxWidth)
    }

    private func edgeLabelEditorHeight(zoomScale: Double) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: edgeLabelFontSize(zoomScale: zoomScale),
            weight: .medium
        )
        // Keep editing height to one line so edge label editor remains compact.
        let contentHeight = font.ascender - font.descender + font.leading
        let insets =
            nodeTextStyle.textContainerInset
            * max(CGFloat(zoomScale), 0.0001)
            * edgeLabelEditorContentScale(zoomScale: zoomScale)
            * 2
        return max(contentHeight + insets, 14)
    }

    private func edgeLabelEditorContentScale(zoomScale: Double) -> Double {
        let baseZoomScale = max(CGFloat(zoomScale), 0.0001)
        let baseFontSize = nodeTextStyle.fontSize * baseZoomScale
        guard baseFontSize > 0 else {
            return 1
        }
        return Double(edgeLabelFontSize(zoomScale: zoomScale) / baseFontSize)
    }

    private func edgeLabelFontSize(zoomScale: Double) -> CGFloat {
        max(11 * CGFloat(zoomScale), 9)
    }
}
