// Background: Multi-window UIs require explicit ownership boundaries so each window edits an independent graph.
// Responsibility: Manage session-scoped use case instances and expose lifecycle operations.
import Domain

@MainActor
/// Application-level store that opens and closes independent canvas sessions.
public final class CanvasSessionStore {
    private var inputPortBySessionID: [CanvasSessionID: ApplyCanvasCommandsUseCase]
    private let defaultMaxHistoryCount: Int

    /// Creates an empty store.
    /// - Parameter defaultMaxHistoryCount: Default undo history capacity for newly opened sessions.
    public init(defaultMaxHistoryCount: Int = 100) {
        inputPortBySessionID = [:]
        self.defaultMaxHistoryCount = max(0, defaultMaxHistoryCount)
    }

    /// Number of sessions currently retained by the store.
    public var sessionCount: Int {
        inputPortBySessionID.count
    }

    /// Opens a new canvas session and returns its runtime handle.
    /// - Parameters:
    ///   - initialGraph: Initial graph for the session.
    ///   - maxHistoryCount: Optional history capacity override.
    /// - Returns: Session metadata and dedicated input port.
    public func openSession(
        initialGraph: CanvasGraph = .empty,
        maxHistoryCount: Int? = nil
    ) -> CanvasSessionHandle {
        let resolvedHistoryCount = maxHistoryCount ?? defaultMaxHistoryCount
        let inputPort = ApplyCanvasCommandsUseCase(
            initialGraph: initialGraph,
            maxHistoryCount: resolvedHistoryCount
        )
        let session = CanvasSession(id: CanvasSessionID())
        inputPortBySessionID[session.id] = inputPort
        return CanvasSessionHandle(
            session: session,
            inputPort: inputPort
        )
    }

    /// Returns the input port bound to a session id when it is active.
    /// - Parameter sessionID: Target session identifier.
    /// - Returns: Session input port. `nil` when the session was never opened or already closed.
    public func inputPort(for sessionID: CanvasSessionID) -> (any CanvasEditingInputPort)? {
        inputPortBySessionID[sessionID]
    }

    /// Closes one session and removes it from store ownership.
    /// - Parameter id: Session identifier.
    /// - Returns: `true` when the session existed and was removed.
    @discardableResult
    public func closeSession(id: CanvasSessionID) -> Bool {
        inputPortBySessionID.removeValue(forKey: id) != nil
    }
}
