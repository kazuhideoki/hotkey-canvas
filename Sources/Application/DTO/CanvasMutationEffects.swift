// Background: Pipeline stages are gated by explicit effect flags instead of command-kind checks.
// Responsibility: Represent stage execution requirements produced by mutation classification.
public struct CanvasMutationEffects: Equatable, Sendable {
    public let didMutateGraph: Bool
    public let needsTreeLayout: Bool
    public let needsAreaLayout: Bool
    public let needsFocusNormalization: Bool

    public init(
        didMutateGraph: Bool,
        needsTreeLayout: Bool,
        needsAreaLayout: Bool,
        needsFocusNormalization: Bool
    ) {
        self.didMutateGraph = didMutateGraph
        self.needsTreeLayout = needsTreeLayout
        self.needsAreaLayout = needsAreaLayout
        self.needsFocusNormalization = needsFocusNormalization
    }

    public static let noEffect = CanvasMutationEffects(
        didMutateGraph: false,
        needsTreeLayout: false,
        needsAreaLayout: false,
        needsFocusNormalization: false
    )
}
