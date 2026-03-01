// Background: Development tools need one place to own the debug HTTP server lifecycle.
// Responsibility: Start and retain local debug state API runtime while the app process is alive.
import Infrastructure
import InterfaceAdapters

/// Holds debug state API server lifetime and startup logs.
final class DebugStateAPIRuntime {
    private let server: CanvasDebugStateHTTPServer?

    init(container: DependencyContainer, logger: any AppLogger = ConsoleLogger()) {
        #if DEBUG
            let options = DebugStateAPILaunchOptions()
            guard options.isEnabled else {
                server = nil
                return
            }

            let configuration = CanvasDebugStateHTTPServerConfiguration(
                port: options.port,
                bearerToken: options.bearerToken
            )
            let server = CanvasDebugStateHTTPServer(
                configuration: configuration,
                fetchResultsBySessionID: {
                    await container.debugStateResultsBySessionID()
                }
            )
            do {
                try server.start()
                logger.info("[debug-state-api] enabled on http://127.0.0.1:\(options.port)")
                logger.info("[debug-state-api] token: \(options.bearerToken)")
            } catch {
                logger.info("[debug-state-api] failed to start: \(error)")
            }
            self.server = server
        #else
            _ = container
            _ = logger
            server = nil
        #endif
    }

    deinit {
        server?.stop()
    }
}
