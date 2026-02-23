// Background: CanvasView keeps rendering in one file while behavior helpers stay separated for maintainability.
// Responsibility: Provide rendering helpers, editing flow handlers, and viewport adjustment logic for CanvasView.
import AppKit
import Domain
import SwiftUI

extension CanvasView {
    static let addNodeModeTreeOptionID = "tree"
    static let addNodeModeDiagramOptionID = "diagram"

    func addNodeModeSelectionOptions() -> [SelectionPopupOption] {
        [
            SelectionPopupOption(
                id: Self.addNodeModeTreeOptionID,
                title: "Tree",
                shortcutLabel: "T"
            ),
            SelectionPopupOption(
                id: Self.addNodeModeDiagramOptionID,
                title: "Diagram",
                shortcutLabel: "D"
            ),
        ]
    }

    func addNodeModeOptionID(for mode: CanvasEditingMode) -> String {
        switch mode {
        case .tree:
            Self.addNodeModeTreeOptionID
        case .diagram:
            Self.addNodeModeDiagramOptionID
        }
    }

    func addNodeMode(from optionID: String) -> CanvasEditingMode {
        switch optionID {
        case Self.addNodeModeTreeOptionID:
            .tree
        case Self.addNodeModeDiagramOptionID:
            .diagram
        default:
            preconditionFailure("Unexpected add-node mode option ID: \(optionID)")
        }
    }

    func presentAddNodeModeSelectionPopup() {
        selectedAddNodeMode = .tree
        isAddNodeModePopupPresented = true
    }

    func dismissAddNodeModeSelectionPopup() {
        isAddNodeModePopupPresented = false
    }

    func commitAddNodeModeSelection(_ mode: CanvasEditingMode) {
        isAddNodeModePopupPresented = false
        Task {
            await viewModel.addNodeFromModeSelection(mode: mode)
        }
    }

    func moveAddNodeModeSelection(delta: Int) {
        guard delta != 0 else {
            return
        }
        switch selectedAddNodeMode {
        case .tree:
            selectedAddNodeMode = .diagram
        case .diagram:
            selectedAddNodeMode = .tree
        }
    }

    func handleAddNodeModePopupHotkey(_ event: NSEvent) -> Bool {
        guard let action = addNodeModeSelectionHotkeyResolver.action(for: event) else {
            // Keep the popup modal: ignore unrelated keys while presented.
            return true
        }

        switch action {
        case .selectTree:
            commitAddNodeModeSelection(.tree)
        case .selectDiagram:
            commitAddNodeModeSelection(.diagram)
        case .moveSelection(let delta):
            moveAddNodeModeSelection(delta: delta)
        case .confirmSelection:
            commitAddNodeModeSelection(selectedAddNodeMode)
        case .dismiss:
            dismissAddNodeModeSelectionPopup()
        }
        return true
    }

    func renderedNode(
        _ node: CanvasNode,
        viewportSize: CGSize,
        effectiveOffset: CGSize
    ) -> CanvasNode {
        let worldRect = CGRect(
            x: node.bounds.x,
            y: node.bounds.y,
            width: node.bounds.width,
            height: node.bounds.height
        )
        let renderedRect = CanvasViewportTransform.rectOnScreen(
            worldRect: worldRect,
            viewportSize: viewportSize,
            zoomScale: zoomScale,
            effectiveOffset: effectiveOffset
        )
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

    func displayNodeForCurrentEditingState(_ node: CanvasNode) -> CanvasNode {
        guard let editingContext, editingContext.nodeID == node.id else {
            return node
        }
        let requiredHeight =
            if isDiagramNode(node.id) {
                node.bounds.height
            } else if editingContext.nodeHeight.isFinite {
                max(editingContext.nodeHeight, 1)
            } else {
                node.bounds.height
            }
        guard requiredHeight != node.bounds.height else {
            return node
        }
        let resizedBounds = CanvasBounds(
            x: node.bounds.x,
            y: node.bounds.y,
            width: node.bounds.width,
            height: requiredHeight
        )
        return CanvasNode(
            id: node.id,
            kind: node.kind,
            text: node.text,
            attachments: node.attachments,
            bounds: resizedBounds,
            metadata: node.metadata,
            markdownStyleEnabled: node.markdownStyleEnabled
        )
    }

    func centerPoint(
        for node: CanvasNode
    ) -> CGPoint {
        CGPoint(
            x: node.bounds.x + (node.bounds.width / 2),
            y: node.bounds.y + (node.bounds.height / 2)
        )
    }

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
        let nodes = viewModel.nodes.map(displayNodeForCurrentEditingState)
        guard !nodes.isEmpty else {
            hasInitializedCameraAnchor = false
            cameraAnchorPoint = .zero
            manualPanOffset = .zero
            return
        }
        guard let focusNode = currentFocusNode(in: nodes) else {
            return
        }

        if !hasInitializedCameraAnchor {
            cameraAnchorPoint = centerPoint(for: focusNode)
            hasInitializedCameraAnchor = true
            manualPanOffset = .zero
        }

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
        let visibleFocusRect = focusRectOnScreen(
            for: focusNode,
            viewportSize: viewportSize,
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

    func editingTextBinding(for nodeID: CanvasNodeID) -> Binding<String> {
        Binding(
            get: {
                guard editingContext?.nodeID == nodeID else {
                    return ""
                }
                return editingContext?.text ?? ""
            },
            set: { updatedText in
                guard var context = editingContext, context.nodeID == nodeID else {
                    return
                }
                context.text = updatedText
                editingContext = context
            }
        )
    }

    func handleTypingInputStart(
        _ event: NSEvent,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> Bool {
        guard
            let context = editingStartResolver.resolve(
                from: event,
                focusedNodeID: viewModel.focusedNodeID,
                nodesByID: nodesByID
            )
        else {
            return false
        }
        guard let node = nodesByID[context.nodeID] else {
            return false
        }

        let measuredLayout = measuredNodeLayout(text: context.text, nodeWidth: node.bounds.width)
        let editingHeight =
            if isDiagramNode(context.nodeID) {
                node.bounds.height
            } else {
                measuredNodeHeightForEditing(
                    text: context.text,
                    measuredTextHeight: Double(measuredLayout.nodeHeight),
                    node: node
                )
            }
        editingContext = NodeEditingContext(
            nodeID: context.nodeID,
            text: context.text,
            nodeWidth: node.bounds.width,
            nodeHeight: editingHeight,
            initialCursorPlacement: context.initialCursorPlacement,
            initialTypingEvent: context.initialTypingEvent
        )
        return true
    }

    func commitNodeEditingIfNeeded() {
        guard let context = editingContext else {
            return
        }
        commitNodeEditing(context)
    }

    func commitNodeEditing() {
        commitNodeEditingIfNeeded()
    }

    func commitNodeEditing(_ context: NodeEditingContext) {
        editingContext = nil
        Task {
            await viewModel.commitNodeText(
                nodeID: context.nodeID,
                text: context.text,
                nodeHeight: context.nodeHeight
            )
        }
    }

    func cancelNodeEditing() {
        editingContext = nil
    }

    func updateEditingNodeLayout(for nodeID: CanvasNodeID, metrics: NodeTextLayoutMetrics) {
        guard var context = editingContext, context.nodeID == nodeID else {
            return
        }
        guard !isDiagramNode(nodeID) else {
            return
        }
        let roundedTextHeight = Double(ceil(metrics.nodeHeight))
        guard roundedTextHeight.isFinite, roundedTextHeight > 0 else {
            return
        }
        guard let node = viewModel.nodes.first(where: { $0.id == nodeID }) else {
            return
        }
        let roundedHeight = measuredNodeHeightForEditing(
            text: context.text,
            measuredTextHeight: roundedTextHeight,
            node: node
        )
        guard roundedHeight.isFinite, roundedHeight > 0 else {
            return
        }
        guard context.nodeHeight != roundedHeight else {
            return
        }
        context.nodeHeight = roundedHeight
        editingContext = context
    }

    func measuredNodeLayout(text: String, nodeWidth: Double) -> NodeTextLayoutMetrics {
        nodeTextHeightMeasurer.measureLayout(text: text, nodeWidth: CGFloat(nodeWidth))
    }

    func isDiagramNode(_ nodeID: CanvasNodeID) -> Bool {
        viewModel.diagramNodeIDs.contains(nodeID)
    }

    @ViewBuilder
    func nodeContentOverlay(
        node: CanvasNode,
        zoomScale: Double,
        contentAlignment: NodeTextContentAlignment
    ) -> some View {
        if editingContext?.nodeID == node.id {
            NodeTextEditor(
                text: editingTextBinding(for: node.id),
                nodeWidth: CGFloat(node.bounds.width),
                zoomScale: zoomScale,
                contentAlignment: contentAlignment,
                selectAllOnFirstFocus: false,
                initialCursorPlacement: editingContext?.initialCursorPlacement ?? .end,
                initialTypingEvent: editingContext?.initialTypingEvent,
                onLayoutMetricsChange: { metrics in
                    updateEditingNodeLayout(for: node.id, metrics: metrics)
                },
                onCommit: {
                    commitNodeEditing()
                },
                onCancel: {
                    cancelNodeEditing()
                }
            )
            .padding(NodeTextStyle.editorContainerPadding * CGFloat(zoomScale))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment.frameAlignment)
        } else {
            nonEditingNodeContent(
                node: node,
                zoomScale: zoomScale
            )
        }
    }

    static func nodeTextContentAlignment(isDiagramNode: Bool) -> NodeTextContentAlignment {
        isDiagramNode ? .center : .topLeading
    }

    func nodeTextContentAlignment(for nodeID: CanvasNodeID) -> NodeTextContentAlignment {
        Self.nodeTextContentAlignment(isDiagramNode: isDiagramNode(nodeID))
    }

    @ViewBuilder
    func nonEditingNodeText(node: CanvasNode, zoomScale: Double) -> some View {
        let text = node.text ?? ""
        let scale = CGFloat(zoomScale)
        let contentAlignment = nodeTextContentAlignment(for: node.id)
        if node.markdownStyleEnabled {
            NodeMarkdownDisplay(
                text: text,
                nodeWidth: node.bounds.width,
                zoomScale: zoomScale,
                contentAlignment: contentAlignment
            )
        } else {
            let scaledPadding = NodeTextStyle.outerPadding * scale
            let textWidth = max((CGFloat(node.bounds.width) * scale) - (scaledPadding * 2), 1)
            Text(text)
                .font(.system(size: NodeTextStyle.fontSize * scale, weight: NodeTextStyle.displayFontWeight))
                .lineLimit(nil)
                .multilineTextAlignment(contentAlignment.textAlignment)
                .frame(width: textWidth, alignment: contentAlignment.frameAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment.frameAlignment)
                .padding(scaledPadding)
        }
    }
}

/// Inline-editing state for a single node.
struct NodeEditingContext: Equatable {
    let nodeID: CanvasNodeID
    var text: String
    let nodeWidth: Double
    var nodeHeight: Double
    let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
    let initialTypingEvent: NSEvent?

    static func == (lhs: NodeEditingContext, rhs: NodeEditingContext) -> Bool {
        lhs.nodeID == rhs.nodeID && lhs.text == rhs.text && lhs.nodeWidth == rhs.nodeWidth
            && lhs.nodeHeight == rhs.nodeHeight && lhs.initialCursorPlacement == rhs.initialCursorPlacement
            && lhs.initialTypingEvent?.timestamp == rhs.initialTypingEvent?.timestamp
    }
}
