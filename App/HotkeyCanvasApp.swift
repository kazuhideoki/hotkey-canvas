import AppKit
import InterfaceAdapters
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
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
struct HotkeyCanvasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            CanvasView(viewModel: container.makeCanvasViewModel())
        }
    }
}
