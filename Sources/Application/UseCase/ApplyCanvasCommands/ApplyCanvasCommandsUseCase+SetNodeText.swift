// Background: Keyboard-first node editing needs text update commands.
// Responsibility: Handle focused-node text updates for inline editing.
import Domain
import Foundation

// Background: Inline editing needs a command path to mutate node text content.
// Responsibility: Update text of an existing node, normalize empty strings to nil,
// and expand node height for multiline text.
extension ApplyCanvasCommandsUseCase {
    private static let nodeTextLineHeight: Double = 20
    private static let nodeTextVerticalPadding: Double = 24

    func setNodeText(in graph: CanvasGraph, nodeID: CanvasNodeID, text: String) throws -> CanvasGraph {
        guard let node = graph.nodesByID[nodeID] else {
            return graph
        }

        let normalizedText = text.isEmpty ? nil : text
        let resizedBounds = resizedBounds(for: node.bounds, text: normalizedText)
        guard node.text != normalizedText || node.bounds != resizedBounds else {
            return graph
        }

        let updatedNode = CanvasNode(
            id: node.id,
            kind: node.kind,
            text: normalizedText,
            bounds: resizedBounds,
            metadata: node.metadata
        )
        return try CanvasGraphCRUDService.updateNode(updatedNode, in: graph)
    }

    private func resizedBounds(for bounds: CanvasBounds, text: String?) -> CanvasBounds {
        let requiredHeight = requiredHeight(for: text, minimumHeight: bounds.height)
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

    private func requiredHeight(for text: String?, minimumHeight: Double) -> Double {
        guard let text, !text.isEmpty else {
            return minimumHeight
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
        return max(minimumHeight, contentHeight)
    }
}
