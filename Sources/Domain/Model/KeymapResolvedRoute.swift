// Background: Routing layer needs one normalized result type shared across adapters and application.
// Responsibility: Represent resolved shortcut route with scope and payload.
/// Result of keymap route resolution.
public enum KeymapResolvedRoute: Equatable, Sendable {
    case primitive(intent: KeymapPrimitiveIntent)
    case global(action: KeymapGlobalAction)
    case modal

    /// Scope extracted from route payload.
    public var scope: KeymapShortcutScope {
        switch self {
        case .primitive:
            return .primitive
        case .global:
            return .global
        case .modal:
            return .modal
        }
    }
}
