// Background: WindowGroup body can be recomputed many times,
// so session creation must be isolated from pure view construction.
// Responsibility: Own one session runtime per window and provide the stable canvas view model.
import Application
import InterfaceAdapters
import SwiftUI

@MainActor
/// Root content for one window that lazily bootstraps and owns a single canvas session runtime.
struct CanvasWindowRootView: View {
    private let container: DependencyContainer
    @State private var runtime: CanvasWindowRuntime?

    init(container: DependencyContainer) {
        self.container = container
    }

    var body: some View {
        Group {
            if let runtime {
                CanvasView(
                    viewModel: runtime.viewModel,
                    onDisappear: runtime.closeSession
                )
            } else {
                Color.clear
            }
        }
        .task {
            bootstrapRuntimeIfNeeded()
        }
    }
}

extension CanvasWindowRootView {
    /// Creates a dedicated session and view model exactly once per window identity.
    private func bootstrapRuntimeIfNeeded() {
        guard runtime == nil else {
            return
        }

        let sessionHandle = container.openCanvasSession()
        let sessionID = sessionHandle.session.id
        let viewModel = CanvasViewModel(inputPort: sessionHandle.inputPort)
        runtime = CanvasWindowRuntime(
            viewModel: viewModel,
            closeSession: { [container] in
                container.closeCanvasSession(id: sessionID)
            }
        )
    }
}

/// Runtime bundle retained by a window root while the window is alive.
private struct CanvasWindowRuntime {
    let viewModel: CanvasViewModel
    let closeSession: () -> Void
}
