// Background: Temporary bootstrap flow needs a minimal domain payload.
// Responsibility: Carry greeting text returned by the bootstrap use case.
// TEMP: Bootstrap-only model for launch smoke test. Remove when domain model is replaced by canvas entities.
/// Temporary domain model used for startup smoke verification.
public struct Greeting: Equatable, Sendable {
    /// Greeting text shown in the bootstrap screen.
    public let text: String

    /// Creates a greeting payload.
    /// - Parameter text: Greeting text.
    public init(text: String) {
        self.text = text
    }
}
