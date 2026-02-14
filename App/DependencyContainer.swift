// Background: App module owns composition root wiring during bootstrap.
// Responsibility: Provide fully constructed objects for UI entry points.
import Application
import InterfaceAdapters

/// Assembles dependencies required by top-level app scenes.
struct DependencyContainer {
<<<<<<< HEAD
    let canvasEditingInputPort: any CanvasEditingInputPort
=======
    // TEMP: Wiring for hello-world bootstrap only. Replace with real composition roots as features are added.
    /// Input boundary consumed by the bootstrap view model.
    let greetingInputPort: any GreetingInputPort
>>>>>>> main

    init() {
        canvasEditingInputPort = ApplyCanvasCommandsUseCase()
    }

    /// Creates the view model instance used by the greeting screen.
    @MainActor
    func makeCanvasViewModel() -> CanvasViewModel {
        CanvasViewModel(inputPort: canvasEditingInputPort)
    }
}
