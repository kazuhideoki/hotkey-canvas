// Background: Inline editing and committed rendering need identical node-height calculation.
// Responsibility: Measure node height from actual AppKit text layout instead of line-count heuristics.
import AppKit

/// Measures node height for a given text and node width using AppKit layout primitives.
struct NodeTextHeightMeasurer {
    private let font: NSFont
    private let outerHorizontalPadding: CGFloat
    private let outerVerticalPadding: CGFloat
    private let textContainerInset: NSSize
    private let lineFragmentPadding: CGFloat
    private let minimumNodeHeight: CGFloat
    private let maximumNodeHeight: CGFloat

    init(
        font: NSFont = .systemFont(ofSize: 14, weight: .medium),
        outerHorizontalPadding: CGFloat = 6,
        outerVerticalPadding: CGFloat = 6,
        textContainerInset: NSSize = NSSize(width: 6, height: 6),
        lineFragmentPadding: CGFloat = 0,
        minimumNodeHeight: CGFloat? = nil,
        maximumNodeHeight: CGFloat = 320
    ) {
        self.font = font
        self.outerHorizontalPadding = outerHorizontalPadding
        self.outerVerticalPadding = outerVerticalPadding
        self.textContainerInset = textContainerInset
        self.lineFragmentPadding = lineFragmentPadding
        let oneLineHeight =
            NSLayoutManager().defaultLineHeight(for: font)
            + (outerVerticalPadding * 2)
            + (textContainerInset.height * 2)
        self.minimumNodeHeight = minimumNodeHeight ?? oneLineHeight
        self.maximumNodeHeight = max(maximumNodeHeight, self.minimumNodeHeight)
    }

    /// Measures node height for the supplied text content.
    /// - Parameters:
    ///   - text: Current editor text.
    ///   - nodeWidth: Node width in canvas coordinates.
    /// - Returns: Height clamped between configured minimum and maximum.
    func measure(text: String, nodeWidth: CGFloat) -> CGFloat {
        let textContainerWidth = max(
            nodeWidth
                - (outerHorizontalPadding * 2)
                - (textContainerInset.width * 2),
            1
        )
        let textHeight = measuredTextHeight(text: text, width: textContainerWidth)
        let nodeHeight =
            textHeight
            + (outerVerticalPadding * 2)
            + (textContainerInset.height * 2)
        return min(ceil(max(nodeHeight, minimumNodeHeight)), maximumNodeHeight)
    }
}

extension NodeTextHeightMeasurer {
    private func measuredTextHeight(text: String, width: CGFloat) -> CGFloat {
        let textStorage = NSTextStorage(
            string: text,
            attributes: [.font: font]
        )
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )

        textContainer.lineFragmentPadding = lineFragmentPadding
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        var lineFragmentCount = 0
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, _, _ in
            lineFragmentCount += 1
        }
        if layoutManager.extraLineFragmentTextContainer != nil {
            lineFragmentCount += 1
        }
        let effectiveLineCount = max(lineFragmentCount, 1)
        let lineHeight = layoutManager.defaultLineHeight(for: font)
        return CGFloat(effectiveLineCount) * lineHeight
    }
}
