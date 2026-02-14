// Background: macOS lifecycle setup is isolated from domain/application logic.
// Responsibility: Define the app entry point and bootstrap root scene.
import AppKit
import InterfaceAdapters
import SwiftUI

/// Bridges NSApplication lifecycle hooks that are needed at startup.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Configures activation behavior for debug launches.
    func applicationDidFinishLaunching(_: Notification) {
        #if DEBUG
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
            }
        #endif
    }
}

@main
/// Main app entry that wires the bootstrap scene.
struct HotkeyCanvasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container = DependencyContainer()

    /// Root scene rendered by the application.
    var body: some Scene {
        WindowGroup {
            CanvasView(viewModel: container.makeCanvasViewModel())
        }
    }
}
