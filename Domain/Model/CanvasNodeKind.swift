public struct CanvasNodeKind: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let text = CanvasNodeKind(rawValue: "text")
    public static let file = CanvasNodeKind(rawValue: "file")
    public static let link = CanvasNodeKind(rawValue: "link")
    public static let group = CanvasNodeKind(rawValue: "group")
}
