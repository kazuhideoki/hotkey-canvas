// Background: Multi-window support needs a stable key to reference each independent canvas session.
// Responsibility: Define immutable identifier values for canvas sessions.
import Foundation

/// Immutable identifier used to address one canvas session.
public struct CanvasSessionID: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String

    /// Creates an identifier from a persisted raw value.
    /// - Parameter rawValue: Stable string identifier.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a new unique identifier for runtime session creation.
    public init() {
        rawValue = UUID().uuidString.lowercased()
    }
}
