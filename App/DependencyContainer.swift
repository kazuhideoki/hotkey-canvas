import Application
import InterfaceAdapters

struct DependencyContainer {
    // TEMP: Wiring for hello-world bootstrap only. Replace with real composition roots as features are added.
    let greetingInputPort: any GreetingInputPort

    init() {
        greetingInputPort = GetGreetingUseCase()
    }

    @MainActor
    func makeGreetingViewModel() -> GreetingViewModel {
        GreetingViewModel(inputPort: greetingInputPort)
    }
}
