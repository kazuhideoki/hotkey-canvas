// Background: Shortcut catalog entries must provide behavior and display metadata from one source.
// Responsibility: Represent one shortcut rule used by event handling and command palette UI.
/// Immutable shortcut catalog entry.
public struct CanvasShortcutDefinition: Equatable, Sendable {
    /// Stable identifier for this shortcut rule.
    public let id: CanvasShortcutID
    /// Human-readable command name.
    public let name: String
    /// Matching gesture.
    public let gesture: CanvasShortcutGesture
    /// Action invoked when the gesture matches.
    public let action: CanvasShortcutAction
    /// Display label for shortcut hints.
    public let shortcutLabel: String
    /// Additional search keywords for command palette filtering.
    public let searchTokens: [String]
    /// Whether this definition should be shown in command palette list.
    public let isVisibleInCommandPalette: Bool

    /// Creates a shortcut catalog entry.
    /// - Parameters:
    ///   - id: Stable identifier.
    ///   - name: Human-readable command name.
    ///   - gesture: Matching gesture.
    ///   - action: Action to invoke.
    ///   - shortcutLabel: UI-facing shortcut hint text.
    ///   - searchTokens: Additional search keywords.
    ///   - isVisibleInCommandPalette: Visibility flag for command palette listing.
    public init(
        id: CanvasShortcutID,
        name: String,
        gesture: CanvasShortcutGesture,
        action: CanvasShortcutAction,
        shortcutLabel: String,
        searchTokens: [String] = [],
        isVisibleInCommandPalette: Bool = true
    ) {
        self.id = id
        self.name = name
        self.gesture = gesture
        self.action = action
        self.shortcutLabel = shortcutLabel
        self.searchTokens = searchTokens
        self.isVisibleInCommandPalette = isVisibleInCommandPalette
    }
}
