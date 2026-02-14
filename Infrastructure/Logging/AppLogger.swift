// Background: Logging backend should be swappable from application/domain call sites.
// Responsibility: Define minimal logging contract and default console adapter.
/// Logging abstraction used by upper layers.
public protocol AppLogger: Sendable {
    /// Emits an informational message.
    /// - Parameter message: Text payload to log.
    func info(_ message: String)
}

/// Console-based logger implementation for local development.
public struct ConsoleLogger: AppLogger {
    public init() {}

    /// Prints informational log text to stdout.
    /// - Parameter message: Text payload to log.
    public func info(_ message: String) {
        print(message)
    }
}
