// Background: Command palette naming must stay consistent as shortcut definitions grow.
// Responsibility: Represent a command palette title in fixed Noun: Verb format.
/// Value object for command palette display labels.
public struct CanvasCommandPaletteLabel: Equatable, Sendable {
    /// Noun part used as command category.
    public let noun: String
    /// Verb phrase describing operation.
    public let verb: String

    /// Creates a command palette label.
    /// - Parameters:
    ///   - noun: Category noun shown before separator.
    ///   - verb: Verb phrase shown after separator.
    public init(noun: String, verb: String) {
        self.noun = noun
        self.verb = verb
    }

    /// UI title with fixed Noun: Verb formatting.
    public var title: String {
        "\(noun): \(verb)"
    }
}
