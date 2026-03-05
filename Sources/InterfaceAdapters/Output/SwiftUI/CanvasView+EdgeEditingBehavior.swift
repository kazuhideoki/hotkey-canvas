// Background: Edge label editing shares CanvasView orchestration but should stay isolated from node behaviors.
// Responsibility: Provide edge-editing state helpers and commit/cancel flows.
import AppKit
import Domain
import SwiftUI

extension CanvasView {
    func displayEdgeForCurrentEditingState(_ edge: CanvasEdge) -> CanvasEdge {
        guard let edgeEditingContext, edgeEditingContext.edgeID == edge.id else {
            return edge
        }
        return CanvasEdge(
            id: edge.id,
            fromNodeID: edge.fromNodeID,
            toNodeID: edge.toNodeID,
            relationType: edge.relationType,
            directionality: edge.directionality,
            parentChildOrder: edge.parentChildOrder,
            label: edgeEditingContext.label.isEmpty ? nil : edgeEditingContext.label,
            metadata: edge.metadata
        )
    }

    func editingEdgeLabelBinding(for edgeID: CanvasEdgeID) -> Binding<String> {
        Binding(
            get: {
                guard edgeEditingContext?.edgeID == edgeID else {
                    return ""
                }
                return edgeEditingContext?.label ?? ""
            },
            set: { updatedLabel in
                guard var context = edgeEditingContext, context.edgeID == edgeID else {
                    return
                }
                context.label = updatedLabel
                edgeEditingContext = context
            }
        )
    }

    func handleEdgeTypingInputStart(
        _ event: NSEvent,
        edgesByID: [CanvasEdgeID: CanvasEdge]
    ) -> Bool {
        guard
            let context = edgeEditingStartResolver.resolve(
                from: event,
                focusedEdgeID: focusedEdgeID,
                edgesByID: edgesByID
            )
        else {
            return false
        }
        edgeEditingContext = EdgeEditingContext(
            edgeID: context.edgeID,
            label: context.label,
            editorHeight: edgeEditingSingleLineHeight(),
            initialCursorPlacement: context.initialCursorPlacement,
            initialTypingEvent: context.initialTypingEvent
        )
        return true
    }

    func commitEdgeEditingIfNeeded() {
        guard let context = edgeEditingContext else {
            return
        }
        commitEdgeEditing(context)
    }

    func commitEdgeEditing(_ context: EdgeEditingContext) {
        edgeEditingContext = nil
        Task {
            await viewModel.commitEdgeLabel(
                edgeID: context.edgeID,
                label: context.label
            )
        }
    }

    func cancelEdgeEditing() {
        edgeEditingContext = nil
    }

    func synchronizeEdgeEditingState() {
        guard let edgeEditingContext else {
            return
        }
        guard operationTargetKind == .edge else {
            cancelEdgeEditing()
            return
        }
        guard focusedEdgeID == edgeEditingContext.edgeID else {
            cancelEdgeEditing()
            return
        }
    }

    func updateEdgeEditingLayout(for edgeID: CanvasEdgeID, metrics: NodeTextLayoutMetrics) {
        guard var context = edgeEditingContext, context.edgeID == edgeID else {
            return
        }
        let roundedHeight = Double(ceil(metrics.nodeHeight))
        guard roundedHeight.isFinite, roundedHeight > 0 else {
            return
        }
        guard context.editorHeight != roundedHeight else {
            return
        }
        context.editorHeight = roundedHeight
        edgeEditingContext = context
    }

    private func edgeEditingSingleLineHeight() -> Double {
        let font = NSFont.systemFont(
            ofSize: max(11 * CGFloat(zoomScale), 9),
            weight: .medium
        )
        let contentHeight = font.ascender - font.descender + font.leading
        let insets =
            nodeTextStyle.textContainerInset
            * max(CGFloat(zoomScale), 0.0001)
            * edgeLabelEditorContentScale(zoomScale: zoomScale)
            * 2
        return Double(max(contentHeight + insets, 14))
    }

    private func edgeLabelEditorContentScale(zoomScale: Double) -> Double {
        let baseZoomScale = max(CGFloat(zoomScale), 0.0001)
        let baseFontSize = nodeTextStyle.fontSize * baseZoomScale
        guard baseFontSize > 0 else {
            return 1
        }
        return Double(max(11 * CGFloat(zoomScale), 9) / baseFontSize)
    }
}

/// Inline-editing state for a single edge.
struct EdgeEditingContext: Equatable {
    let edgeID: CanvasEdgeID
    var label: String
    var editorHeight: Double
    let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
    let initialTypingEvent: NSEvent?

    static func == (lhs: EdgeEditingContext, rhs: EdgeEditingContext) -> Bool {
        lhs.edgeID == rhs.edgeID && lhs.label == rhs.label && lhs.editorHeight == rhs.editorHeight
            && lhs.initialCursorPlacement == rhs.initialCursorPlacement
            && lhs.initialTypingEvent?.timestamp == rhs.initialTypingEvent?.timestamp
    }
}
