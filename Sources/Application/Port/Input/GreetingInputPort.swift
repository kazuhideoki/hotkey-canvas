// Background: Application use cases are consumed through explicit input boundaries.
// Responsibility: Define a read-only greeting retrieval contract for the UI layer.
import Domain

/// Input port for obtaining greeting content.
public protocol GreetingInputPort: Sendable {
    /// Fetches the greeting shown on initial screen load.
    /// - Returns: Greeting text model for presentation.
    func getGreeting() async -> Greeting
}
