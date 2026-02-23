// Background: Node content must support multiple non-text payloads beyond images.
// Responsibility: Represent one immutable attachment item owned by a node.
/// Immutable attachment entity associated with a node.
public struct CanvasAttachment: Equatable, Sendable {
    /// Unique attachment identifier scoped to the node.
    public let id: CanvasAttachmentID
    /// Semantic attachment kind and payload.
    public let kind: CanvasAttachmentKind
    /// Placement rule used by renderers and layout calculators.
    public let placement: CanvasAttachmentPlacement

    /// Creates an immutable attachment value.
    /// - Parameters:
    ///   - id: Unique attachment identifier.
    ///   - kind: Semantic kind and payload.
    ///   - placement: Placement rule in the node content.
    public init(
        id: CanvasAttachmentID,
        kind: CanvasAttachmentKind,
        placement: CanvasAttachmentPlacement
    ) {
        self.id = id
        self.kind = kind
        self.placement = placement
    }
}

extension CanvasAttachment {
    /// Returns file path when attachment kind is image.
    public var imageFilePath: String? {
        switch kind {
        case .image(let filePath):
            return filePath
        }
    }
}

/// Supported attachment kinds.
public enum CanvasAttachmentKind: Equatable, Sendable {
    /// Image attachment represented by absolute file path.
    case image(filePath: String)
}

/// Placement rule for node attachment rendering.
public enum CanvasAttachmentPlacement: Equatable, Sendable {
    /// Renders attachment above node text.
    case aboveText
}
