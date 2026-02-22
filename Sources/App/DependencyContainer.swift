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

    /// Creates one canvas view backed by a dedicated editing session.
    func makeCanvasView() -> CanvasView {
        let sessionHandle = canvasSessionStore.openSession()
        let sessionID = sessionHandle.session.id
        let viewModel = CanvasViewModel(inputPort: sessionHandle.inputPort)
        return CanvasView(
            viewModel: viewModel,
            onDisappear: { [canvasSessionStore] in
                canvasSessionStore.closeSession(id: sessionID)
            }
        )
    }
}
