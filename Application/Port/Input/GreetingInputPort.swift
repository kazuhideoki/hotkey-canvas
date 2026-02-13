import Domain

public protocol GreetingInputPort: Sendable {
    func getGreeting() async -> Greeting
}
