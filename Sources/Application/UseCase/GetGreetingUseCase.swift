// Background: Bootstrap phase validates architecture wiring with a minimal use case.
// Responsibility: Provide static greeting text via the application input port.
import Domain

// TEMP: Bootstrap-only use case for initial macOS launch validation. Remove after real canvas flow is implemented.
/// Temporary greeting retrieval use case used during initial app bootstrap.
public struct GetGreetingUseCase: GreetingInputPort {
    public init() {}

    /// Returns a static greeting while the canvas feature is not yet implemented.
    /// - Returns: Greeting model containing bootstrap text.
    public func getGreeting() async -> Greeting {
        Greeting(text: "hello world")
    }
}
