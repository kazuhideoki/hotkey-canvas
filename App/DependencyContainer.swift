// Background: App module owns composition root wiring during bootstrap.
// Responsibility: Provide fully constructed objects for UI entry points.
import Application
import InterfaceAdapters

/// Assembles dependencies required by top-level app scenes.
struct DependencyContainer {
    let canvasEditingInputPort: any CanvasEditingInputPort

    init() {
        canvasEditingInputPort = ApplyCanvasCommandsUseCase()
    }

    /// Creates the view model instance used by the canvas screen.
    @MainActor
    func makeCanvasViewModel() -> CanvasViewModel {
        CanvasViewModel(inputPort: canvasEditingInputPort)
    }
}
