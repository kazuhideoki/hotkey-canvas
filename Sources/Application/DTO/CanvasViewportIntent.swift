// Background: Viewport behavior decisions must be expressed in Application without UI-framework coupling.
// Responsibility: Describe viewport actions for adapters to interpret.
/// Viewport action intent emitted by the application pipeline.
public enum CanvasViewportIntent: Equatable, Sendable {
    case resetManualPanOffset
}
