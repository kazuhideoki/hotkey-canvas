// Background: Development-only features must be opt-in from app launch arguments.
// Responsibility: Parse debug state API launch options in a deterministic way.
import Foundation

/// Parsed launch options for the local debug state API.
struct DebugStateAPILaunchOptions {
    let isEnabled: Bool
    let port: UInt16
    let bearerToken: String

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        isEnabled = arguments.contains("--enable-debug-state-api")
        port = Self.resolvePort(arguments: arguments)
        bearerToken = Self.resolveBearerToken(arguments: arguments)
    }
}

extension DebugStateAPILaunchOptions {
    private static func resolvePort(arguments: [String]) -> UInt16 {
        let prefix = "--debug-state-port="
        for argument in arguments {
            guard argument.hasPrefix(prefix) else {
                continue
            }
            let value = String(argument.dropFirst(prefix.count))
            guard let rawPort = UInt16(value), rawPort > 0 else {
                continue
            }
            return rawPort
        }
        return 8750
    }

    private static func resolveBearerToken(arguments: [String]) -> String {
        let prefix = "--debug-state-token="
        for argument in arguments {
            guard argument.hasPrefix(prefix) else {
                continue
            }
            let token = String(argument.dropFirst(prefix.count))
            guard token.isEmpty == false else {
                continue
            }
            return token
        }
        return UUID().uuidString.lowercased()
    }
}
