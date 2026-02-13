import InterfaceAdapters
import SwiftUI

// TEMP: Entry scene for hello-world bootstrap. Replace root view with canvas feature UI.
@main
struct HotkeyCanvasApp: App {
    private let container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            GreetingView(viewModel: container.makeGreetingViewModel())
        }
    }
}
