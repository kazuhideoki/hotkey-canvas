// Background: Domain tests construct many sample nodes where image content is not relevant.
// Responsibility: Provide a test-only convenience initializer that defaults attachments to empty.
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
            attachments: [],
            bounds: bounds,
            metadata: metadata,
            markdownStyleEnabled: markdownStyleEnabled
        )
    }
}
