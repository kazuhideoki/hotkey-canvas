// Background: Primitive intent requires an application-facing action boundary before command dispatch.
// Responsibility: Represent context-aware actions produced from primitive intent.
import Domain

/// Context-dependent action derived from primitive intent.
public enum KeymapContextAction: Equatable, Sendable {
    case apply(commands: [CanvasCommand])
    case beginConnectNodeSelection
    case presentAddNodeModeSelection
    case reportUnsupportedIntent(intent: KeymapPrimitiveIntent)
}
