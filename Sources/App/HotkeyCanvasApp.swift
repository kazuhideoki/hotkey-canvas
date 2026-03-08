// Background: macOS lifecycle setup is isolated from domain/application logic.
// Responsibility: Define the app entry point and bootstrap root scene.
import AppKit
import SwiftUI

private enum WindowLaunchBehavior {
    static let autoZoomEnvironmentKey = "HOTKEY_CANVAS_AUTO_ZOOM_WINDOW"

    static func shouldAutoZoomWindow() -> Bool {
        ProcessInfo.processInfo.environment[autoZoomEnvironmentKey] == "1"
    }
}

/// Bridges NSApplication lifecycle hooks that are needed at startup.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Configures activation behavior for debug launches.
    func applicationDidFinishLaunching(_: Notification) {
        #if DEBUG
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                guard let window = NSApplication.shared.windows.first else {
                    return
                }
                window.makeKeyAndOrderFront(nil)
                guard WindowLaunchBehavior.shouldAutoZoomWindow() else {
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    window.zoom(nil)
                }
            }
        #endif
    }
}

@main
/// Main app entry that wires the bootstrap scene.
@MainActor
struct HotkeyCanvasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: DependencyContainer
    private let debugStateAPIRuntime: DebugStateAPIRuntime

    init() {
        let container = DependencyContainer()
        self.container = container
        debugStateAPIRuntime = DebugStateAPIRuntime(container: container)
    }

    /// Root scene rendered by the application.
    var body: some Scene {
        WindowGroup {
            CanvasWindowRootView(container: container)
                .onAppear {
                    _ = debugStateAPIRuntime
                }
        }
    }
}
