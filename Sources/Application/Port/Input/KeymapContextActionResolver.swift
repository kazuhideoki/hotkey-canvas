// Background: Primitive shortcut routing needs a stable application port to map intent into concrete behavior.
// Responsibility: Define contract for context-specific action resolution from primitive intent.
import Domain

/// Input port for resolving primitive intent into context actions.
public protocol KeymapContextActionResolver: Sendable {
    /// Resolves a primitive intent into a context action.
    /// - Parameter primitiveIntent: Primitive intent that already passed scope classification.
    /// - Returns: Context-aware action to execute.
    func resolve(primitiveIntent: KeymapPrimitiveIntent) -> KeymapContextAction
}
