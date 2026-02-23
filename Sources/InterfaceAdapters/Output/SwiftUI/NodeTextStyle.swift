// Background: Node typography is shared between rendering and editing paths.
// Responsibility: Provide a single source of truth for node text defaults.
import AppKit
import Application
import SwiftUI

/// Shared defaults used for node text rendering and measurement.
/// Future work: When node chrome style customization expands, split this into
/// a broader `NodeVisualStyle` (or text/chrome-specific style types).
struct NodeTextStyle {
    private let raw: CanvasNodeTextStyle

    init(styleSheet: CanvasStyleSheet) {
        raw = styleSheet.nodeText
    }

    static let defaultStyle = NodeTextStyle(styleSheet: CanvasStylePalette.defaultStyleSheet)

    let fontWeight: NSFont.Weight = .medium
    let displayFontWeight: Font.Weight = .medium

    var fontSize: CGFloat { CGFloat(raw.fontSize) }
    var outerPadding: CGFloat { CGFloat(raw.outerPadding) }
    var editorContainerPadding: CGFloat { CGFloat(raw.editorContainerPadding) }
    var textContainerInset: CGFloat { CGFloat(raw.textContainerInset) }
    var imageTextSpacing: CGFloat { CGFloat(raw.imageTextSpacing) }
    var imageCornerRadius: CGFloat { CGFloat(raw.imageCornerRadius) }
    var cornerRadius: CGFloat { CGFloat(raw.cornerRadius) }
    var borderLineWidth: CGFloat { CGFloat(raw.borderLineWidth) }
    var focusedBorderLineWidth: CGFloat { CGFloat(raw.focusedBorderLineWidth) }
    var collapsedBadgeFontSize: CGFloat { CGFloat(raw.collapsedBadgeFontSize) }
    var collapsedBadgeTrailingOffset: CGFloat { CGFloat(raw.collapsedBadgeTrailingOffset) }
    var markdownLineSpacing: CGFloat { CGFloat(raw.markdownLineSpacing) }
    var markdownBlockSpacing: CGFloat { CGFloat(raw.markdownBlockSpacing) }
    var markdownListMarkerSpacing: CGFloat { CGFloat(raw.markdownListMarkerSpacing) }
    var markdownCodeFontSize: CGFloat { CGFloat(raw.markdownCodeFontSize) }
    var markdownCodeBlockPadding: CGFloat { CGFloat(raw.markdownCodeBlockPadding) }
    var markdownCodeBlockCornerRadius: CGFloat { CGFloat(raw.markdownCodeBlockCornerRadius) }
    var markdownCodeBlockOpacity: CGFloat { CGFloat(raw.markdownCodeBlockOpacity) }
    var markdownCodeBorderLineWidth: CGFloat { CGFloat(raw.markdownCodeBorderLineWidth) }
    var markdownCodeBorderOpacity: CGFloat { CGFloat(raw.markdownCodeBorderOpacity) }
    var markdownCodeLeadingBarWidth: CGFloat { CGFloat(raw.markdownCodeLeadingBarWidth) }
    var markdownCodeLeadingBarOpacity: CGFloat { CGFloat(raw.markdownCodeLeadingBarOpacity) }
    var markdownCodeTextOpacity: CGFloat { CGFloat(raw.markdownCodeTextOpacity) }

    var font: NSFont {
        .systemFont(ofSize: fontSize, weight: fontWeight)
    }

    static let fontWeight: NSFont.Weight = defaultStyle.fontWeight
    static let displayFontWeight: Font.Weight = defaultStyle.displayFontWeight
    static let fontSize: CGFloat = defaultStyle.fontSize
    static let outerPadding: CGFloat = defaultStyle.outerPadding
    static let editorContainerPadding: CGFloat = defaultStyle.editorContainerPadding
    static let textContainerInset: CGFloat = defaultStyle.textContainerInset
    static let imageTextSpacing: CGFloat = defaultStyle.imageTextSpacing
    static let imageCornerRadius: CGFloat = defaultStyle.imageCornerRadius
    static let cornerRadius: CGFloat = defaultStyle.cornerRadius
    static let borderLineWidth: CGFloat = defaultStyle.borderLineWidth
    static let focusedBorderLineWidth: CGFloat = defaultStyle.focusedBorderLineWidth
    static let collapsedBadgeFontSize: CGFloat = defaultStyle.collapsedBadgeFontSize
    static let collapsedBadgeTrailingOffset: CGFloat = defaultStyle.collapsedBadgeTrailingOffset
    static let markdownLineSpacing: CGFloat = defaultStyle.markdownLineSpacing
    static let markdownBlockSpacing: CGFloat = defaultStyle.markdownBlockSpacing
    static let markdownListMarkerSpacing: CGFloat = defaultStyle.markdownListMarkerSpacing
    static let markdownCodeFontSize: CGFloat = defaultStyle.markdownCodeFontSize
    static let markdownCodeBlockPadding: CGFloat = defaultStyle.markdownCodeBlockPadding
    static let markdownCodeBlockCornerRadius: CGFloat = defaultStyle.markdownCodeBlockCornerRadius
    static let markdownCodeBlockOpacity: CGFloat = defaultStyle.markdownCodeBlockOpacity
    static let markdownCodeBorderLineWidth: CGFloat = defaultStyle.markdownCodeBorderLineWidth
    static let markdownCodeBorderOpacity: CGFloat = defaultStyle.markdownCodeBorderOpacity
    static let markdownCodeLeadingBarWidth: CGFloat = defaultStyle.markdownCodeLeadingBarWidth
    static let markdownCodeLeadingBarOpacity: CGFloat = defaultStyle.markdownCodeLeadingBarOpacity
    static let markdownCodeTextOpacity: CGFloat = defaultStyle.markdownCodeTextOpacity

    static var font: NSFont { defaultStyle.font }
}
