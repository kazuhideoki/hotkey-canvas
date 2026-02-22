// Background: Callers need both session metadata and edit entrypoint when opening a new canvas session.
// Responsibility: Bundle session identity with its dedicated editing input port.
/// Runtime handle returned when a canvas session is opened.
public struct CanvasSessionHandle: Sendable {
    public let session: CanvasSession
    public let inputPort: any CanvasEditingInputPort

    /// Creates a session handle.
    /// - Parameters:
    ///   - session: Session metadata.
    ///   - inputPort: Dedicated editing entrypoint for the session.
    public init(
        session: CanvasSession,
        inputPort: any CanvasEditingInputPort
    ) {
        self.session = session
        self.inputPort = inputPort
    }
}
