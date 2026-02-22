// Background: Application tests build many fixture nodes and should focus on behavior intent.
// Responsibility: Provide a test-only convenience initializer that defaults imagePath to nil.
import Domain

extension CanvasNode {
    init(
        id: CanvasNodeID,
        kind: CanvasNodeKind,
        text: String?,
        bounds: CanvasBounds,
        metadata: [String: String] = [:],
        markdownStyleEnabled: Bool = true
    ) {
        self.init(
            id: id,
            kind: kind,
            text: text,
            imagePath: nil,
            bounds: bounds,
            metadata: metadata,
            markdownStyleEnabled: markdownStyleEnabled
        )
    }
}
