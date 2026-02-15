// Background: CanvasView keeps rendering in one file while behavior helpers stay separated for maintainability.
// Responsibility: Provide rendering helpers, editing flow handlers, and viewport adjustment logic for CanvasView.
import AppKit
import Domain
import SwiftUI

extension CanvasView {
    func displayNodeForCurrentEditingState(_ node: CanvasNode) -> CanvasNode {
        guard let editingContext, editingContext.nodeID == node.id else {
            return node
        }
        let requiredHeight =
            if editingContext.nodeHeight.isFinite {
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
            bounds: resizedBounds,
            metadata: node.metadata
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

    func cameraOffset(for nodes: [CanvasNode], viewportSize: CGSize) -> CGSize {
        guard !nodes.isEmpty else {
            return .zero
        }

        let focusNode =
            if let focusedNodeID = viewModel.focusedNodeID {
                nodes.first(where: { $0.id == focusedNodeID }) ?? nodes[0]
            } else {
                nodes[0]
            }
        let focusCenter = centerPoint(for: focusNode)
        return CGSize(
            width: (viewportSize.width / 2) - focusCenter.x,
            height: (viewportSize.height / 2) - focusCenter.y
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

        let measuredHeight = measuredNodeHeight(text: context.text, nodeWidth: node.bounds.width)
        editingContext = NodeEditingContext(
            nodeID: context.nodeID,
            text: context.text,
            nodeWidth: node.bounds.width,
            nodeHeight: measuredHeight,
            initialCursorPlacement: context.initialCursorPlacement
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

    func updateEditingNodeHeight(for nodeID: CanvasNodeID, measuredHeight: CGFloat) {
        guard var context = editingContext, context.nodeID == nodeID else {
            return
        }
        let roundedHeight = Double(ceil(measuredHeight))
        guard roundedHeight.isFinite, roundedHeight > 0 else {
            return
        }
        guard context.nodeHeight != roundedHeight else {
            return
        }
        context.nodeHeight = roundedHeight
        editingContext = context
    }

    func measuredNodeHeight(text: String, nodeWidth: Double) -> Double {
        Double(nodeTextHeightMeasurer.measure(text: text, nodeWidth: CGFloat(nodeWidth)))
    }

    func startInitialNodeEditingIfNeeded(nodeID: CanvasNodeID?) {
        guard editingContext == nil, let nodeID else {
            return
        }
        guard let node = viewModel.nodes.first(where: { $0.id == nodeID }) else {
            return
        }
        let measuredHeight = measuredNodeHeight(text: node.text ?? "", nodeWidth: node.bounds.width)
        editingContext = NodeEditingContext(
            nodeID: nodeID,
            text: node.text ?? "",
            nodeWidth: node.bounds.width,
            nodeHeight: measuredHeight,
            initialCursorPlacement: .end
        )
    }
}

/// Inline-editing state for a single node.
struct NodeEditingContext: Equatable {
    let nodeID: CanvasNodeID
    var text: String
    let nodeWidth: Double
    var nodeHeight: Double
    let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
}
