import Domain

// TEMP: Bootstrap-only use case for initial macOS launch validation. Remove after real canvas flow is implemented.
public struct GetGreetingUseCase: GreetingInputPort {
    public init() {}

    public func getGreeting() async -> Greeting {
        Greeting(text: "hello world")
    }
}
