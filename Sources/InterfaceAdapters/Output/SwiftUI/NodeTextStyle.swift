// Background: Node typography is shared between rendering and editing paths.
// Responsibility: Provide a single source of truth for node text defaults.
import AppKit
import SwiftUI

/// Shared defaults used for node text rendering and measurement.
/// Future work: When node chrome style customization expands, split this into
/// a broader `NodeVisualStyle` (or text/chrome-specific style types).
enum NodeTextStyle {
    static let fontSize: CGFloat = 20
    static let fontWeight: NSFont.Weight = .medium
    static let displayFontWeight: Font.Weight = .medium
    static let outerPadding: CGFloat = 12
    static let editorContainerPadding: CGFloat = 6
    static let textContainerInset: CGFloat = 6
    static let imageTextSpacing: CGFloat = 10
    static let imageCornerRadius: CGFloat = 6
    static let cornerRadius: CGFloat = 10
    static let borderLineWidth: CGFloat = 2.25
    static let focusedBorderLineWidth: CGFloat = 3
    static let collapsedBadgeFontSize: CGFloat = 15
    static let collapsedBadgeTrailingOffset: CGFloat = 11

    static var font: NSFont {
        .systemFont(ofSize: fontSize, weight: fontWeight)
    }
}
