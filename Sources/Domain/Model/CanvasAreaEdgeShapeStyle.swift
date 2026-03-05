// Background: Area-level edge presentation must be switchable without changing edge domain data.
// Responsibility: Represent area-scoped edge shape style used by UI routing.
/// Edge shape style applied to all edges that belong to one area.
public enum CanvasAreaEdgeShapeStyle: Equatable, Sendable {
    case legacy
    case straight
    case curved

    /// Returns the next style in toggle order.
    public var toggled: Self {
        switch self {
        case .legacy:
            return .curved
        case .curved:
            return .straight
        case .straight:
            return .legacy
        }
    }
}
