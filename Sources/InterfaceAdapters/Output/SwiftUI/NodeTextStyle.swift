// Background: Node typography is shared between rendering and editing paths.
// Responsibility: Provide a single source of truth for node text defaults.
import AppKit

/// Shared defaults used for node text rendering and measurement.
enum NodeTextStyle {
    static let fontSize: CGFloat = 20
    static let fontWeight: NSFont.Weight = .medium

    static var font: NSFont {
        .systemFont(ofSize: fontSize, weight: fontWeight)
    }
}
