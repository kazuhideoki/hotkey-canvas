// Background: Keymap routing needs an explicit first-level boundary before intent resolution.
// Responsibility: Classify shortcut handling path as primitive/global/modal.
/// Top-level shortcut handling scope.
public enum KeymapShortcutScope: Equatable, Sendable {
    case primitive
    case global
    case modal
}
