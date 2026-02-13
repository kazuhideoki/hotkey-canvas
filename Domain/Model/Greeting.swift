// TEMP: Bootstrap-only model for launch smoke test. Remove when domain model is replaced by canvas entities.
public struct Greeting: Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}
