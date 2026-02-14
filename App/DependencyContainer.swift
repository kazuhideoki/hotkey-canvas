import Application
import InterfaceAdapters

struct DependencyContainer {
    let canvasEditingInputPort: any CanvasEditingInputPort

    init() {
        canvasEditingInputPort = ApplyCanvasCommandsUseCase()
    }

    @MainActor
    func makeCanvasViewModel() -> CanvasViewModel {
        CanvasViewModel(inputPort: canvasEditingInputPort)
    }
}
