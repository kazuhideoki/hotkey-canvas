public struct CanvasEdgeRelationType: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let normal = CanvasEdgeRelationType(rawValue: "normal")
    public static let parentChild = CanvasEdgeRelationType(rawValue: "parent-child")
}
