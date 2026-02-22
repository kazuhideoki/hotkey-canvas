// Background: App module owns composition root wiring during bootstrap.
// Responsibility: Provide fully constructed objects for UI entry points.
import Application
import InterfaceAdapters

/// Assembles dependencies required by top-level app scenes.
@MainActor
struct DependencyContainer {
    private let canvasSessionStore: CanvasSessionStore

    init() {
        canvasSessionStore = CanvasSessionStore()
    }

    init(canvasSessionStore: CanvasSessionStore) {
        self.canvasSessionStore = canvasSessionStore
    }

    /// Opens one dedicated canvas editing session for a window.
    func openCanvasSession() -> CanvasSessionHandle {
        canvasSessionStore.openSession()
    }

    /// Closes a canvas editing session by id.
    @discardableResult
    func closeCanvasSession(id: CanvasSessionID) -> Bool {
        canvasSessionStore.closeSession(id: id)
    }
}
