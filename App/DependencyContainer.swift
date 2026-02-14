// Background: App module owns composition root wiring during bootstrap.
// Responsibility: Provide fully constructed objects for UI entry points.
import Application
import InterfaceAdapters

/// Assembles dependencies required by top-level app scenes.
struct DependencyContainer {
    // TEMP: Wiring for hello-world bootstrap only. Replace with real composition roots as features are added.
    /// Input boundary consumed by the bootstrap view model.
    let greetingInputPort: any GreetingInputPort

    init() {
        greetingInputPort = GetGreetingUseCase()
    }

    /// Creates the view model instance used by the greeting screen.
    @MainActor
    func makeGreetingViewModel() -> GreetingViewModel {
        GreetingViewModel(inputPort: greetingInputPort)
    }
}
