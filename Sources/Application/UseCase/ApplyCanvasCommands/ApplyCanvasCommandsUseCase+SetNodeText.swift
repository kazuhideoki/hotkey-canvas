// Background: Keyboard-first node editing needs text update commands.
// Responsibility: Handle focused-node text updates for inline editing.
import Domain
import Foundation

// Background: Inline editing needs a command path to mutate node text content.
// Responsibility: Update text of an existing node, normalize empty strings to nil,
// and expand node height for multiline text.
extension ApplyCanvasCommandsUseCase {
<<<<<<< HEAD
    private static let minimumNodeHeight: Double = 1

    func setNodeText(
        in graph: CanvasGraph,
        nodeID: CanvasNodeID,
        text: String,
        nodeHeight: Double
    ) throws -> CanvasGraph {
=======
    private static let nodeTextLineHeight: Double = 20
    private static let nodeTextVerticalPadding: Double = 24
    private static let minimumTextNodeHeight: Double = 120

    func setNodeText(in graph: CanvasGraph, nodeID: CanvasNodeID, text: String) throws -> CanvasGraph {
>>>>>>> main
        guard let node = graph.nodesByID[nodeID] else {
            return graph
        }

        let normalizedText = text.isEmpty ? nil : text
<<<<<<< HEAD
        let fallbackHeight =
            if node.bounds.height.isFinite, node.bounds.height > Self.minimumNodeHeight {
                node.bounds.height
            } else {
                Self.minimumNodeHeight
            }
        let proposedHeight = nodeHeight.isFinite ? nodeHeight : fallbackHeight
        let normalizedHeight = max(proposedHeight, Self.minimumNodeHeight)
        if node.text == normalizedText, node.bounds.height == normalizedHeight {
=======
        let resizedBounds = resizedBounds(for: node.bounds, text: normalizedText)
        guard node.text != normalizedText || node.bounds != resizedBounds else {
>>>>>>> main
            return graph
        }

        let updatedBounds = CanvasBounds(
            x: node.bounds.x,
            y: node.bounds.y,
            width: node.bounds.width,
            height: normalizedHeight
        )

        let updatedNode = CanvasNode(
            id: node.id,
            kind: node.kind,
            text: normalizedText,
<<<<<<< HEAD
            bounds: updatedBounds,
=======
            bounds: resizedBounds,
>>>>>>> main
            metadata: node.metadata
        )
        return try CanvasGraphCRUDService.updateNode(updatedNode, in: graph)
    }

    private func resizedBounds(for bounds: CanvasBounds, text: String?) -> CanvasBounds {
        let requiredHeight = requiredHeight(for: text, baselineHeight: baselineHeight(for: bounds))
        guard requiredHeight != bounds.height else {
            return bounds
        }
        return CanvasBounds(
            x: bounds.x,
            y: bounds.y,
            width: bounds.width,
            height: requiredHeight
        )
    }

    private func baselineHeight(for bounds: CanvasBounds) -> Double {
        min(bounds.height, Self.minimumTextNodeHeight)
    }

    private func requiredHeight(for text: String?, baselineHeight: Double) -> Double {
        guard let text, !text.isEmpty else {
            return baselineHeight
        }
        let normalizedText =
            text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lineCount =
            normalizedText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
        let contentHeight = (Double(max(1, lineCount)) * Self.nodeTextLineHeight) + Self.nodeTextVerticalPadding
        return max(baselineHeight, contentHeight)
    }
}
