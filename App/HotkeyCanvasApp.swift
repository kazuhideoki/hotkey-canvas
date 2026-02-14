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

// TEMP: Entry scene for hello-world bootstrap. Replace root view with canvas feature UI.
@main
struct HotkeyCanvasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            GreetingView(viewModel: container.makeGreetingViewModel())
        }
    }
}
