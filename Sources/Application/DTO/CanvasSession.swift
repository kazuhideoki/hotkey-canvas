// Background: Window orchestration needs a lightweight model that represents one editable canvas slot.
// Responsibility: Describe one canvas session identity in application-level coordination flows.
/// Immutable session model used by window-level lifecycle management.
public struct CanvasSession: Equatable, Sendable {
    public let id: CanvasSessionID

    /// Creates a session model.
    /// - Parameter id: Session identifier.
    public init(id: CanvasSessionID) {
        self.id = id
    }
}
