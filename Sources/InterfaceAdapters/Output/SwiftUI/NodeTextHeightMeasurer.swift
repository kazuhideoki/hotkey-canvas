// Background: Inline editing and committed rendering need identical node-height calculation.
// Responsibility: Measure node height from actual AppKit text layout instead of line-count heuristics.
import AppKit

/// Result of text layout measurement used by both editing and display paths.
struct NodeTextLayoutMetrics: Equatable {
    let nodeHeight: CGFloat
}

/// Measures node height for a given text and node width using AppKit layout primitives.
struct NodeTextHeightMeasurer {
    private let font: NSFont
    private let outerHorizontalPadding: CGFloat
    private let outerVerticalPadding: CGFloat
    private let textContainerInset: NSSize
    private let lineFragmentPadding: CGFloat
    private let verticalSafetyPadding: CGFloat
    private let minimumNodeHeight: CGFloat
    private let maximumNodeHeight: CGFloat

    init(
        font: NSFont = .systemFont(ofSize: NodeTextStyle.fontSize, weight: NodeTextStyle.fontWeight),
        outerHorizontalPadding: CGFloat = NodeTextStyle.editorContainerPadding,
        outerVerticalPadding: CGFloat = NodeTextStyle.editorContainerPadding,
        textContainerInset: NSSize = NSSize(
            width: NodeTextStyle.textContainerInset,
            height: NodeTextStyle.textContainerInset
        ),
        lineFragmentPadding: CGFloat = 0,
        verticalSafetyPadding: CGFloat = 1,
        minimumNodeHeight: CGFloat? = nil,
        maximumNodeHeight: CGFloat = .greatestFiniteMagnitude
    ) {
        self.font = font
        self.outerHorizontalPadding = outerHorizontalPadding
        self.outerVerticalPadding = outerVerticalPadding
        self.textContainerInset = textContainerInset
        self.lineFragmentPadding = lineFragmentPadding
        self.verticalSafetyPadding = verticalSafetyPadding
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
        measureLayout(text: text, nodeWidth: nodeWidth).nodeHeight
    }

    /// Measures node layout metrics for the supplied text content.
    /// - Parameters:
    ///   - text: Current editor text.
    ///   - nodeWidth: Node width in canvas coordinates.
    /// - Returns: Height derived from AppKit layout.
    func measureLayout(text: String, nodeWidth: CGFloat) -> NodeTextLayoutMetrics {
        let textContainerWidth = max(
            nodeWidth
                - (outerHorizontalPadding * 2)
                - (textContainerInset.width * 2),
            1
        )
        let textLayout = measuredTextLayout(text: text, width: textContainerWidth)
        let nodeHeight =
            textLayout.contentHeight
            + (outerVerticalPadding * 2)
            + (textContainerInset.height * 2)
            + verticalSafetyPadding
        let clampedHeight = min(ceil(max(nodeHeight, minimumNodeHeight)), maximumNodeHeight)
        return NodeTextLayoutMetrics(
            nodeHeight: clampedHeight
        )
    }
}

extension NodeTextHeightMeasurer {
    private struct TextLayoutMeasurement {
        let contentHeight: CGFloat
    }

    private func measuredTextLayout(text: String, width: CGFloat) -> TextLayoutMeasurement {
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
        layoutManager.ensureLayout(forGlyphRange: glyphRange)
        let defaultLineHeight = layoutManager.defaultLineHeight(for: font)
        var lineHeights: [CGFloat] = []
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
            lineHeights.append(max(usedRect.height, defaultLineHeight))
        }

        var measuredHeight = lineHeights.reduce(0, +)
        if layoutManager.extraLineFragmentTextContainer != nil {
            measuredHeight += max(lineHeights.last ?? 0, defaultLineHeight)
        }
        return TextLayoutMeasurement(
            contentHeight: max(measuredHeight, defaultLineHeight)
        )
    }
}
