// Background: Committed node text should support common markdown-style visual hierarchy.
// Responsibility: Render non-editing node text with heading, list, and code-block presentation.
import Foundation
import SwiftUI

/// Markdown-styled renderer used for committed node text display.
struct NodeMarkdownDisplay: View {
    let text: String
    let nodeWidth: Double
    let zoomScale: Double
    let appliesOuterPadding: Bool
    let style: NodeTextStyle
    let contentAlignment: NodeTextContentAlignment

    init(
        text: String,
        nodeWidth: Double,
        zoomScale: Double,
        appliesOuterPadding: Bool = true,
        style: NodeTextStyle = .defaultStyle,
        contentAlignment: NodeTextContentAlignment = .topLeading
    ) {
        self.text = text
        self.nodeWidth = nodeWidth
        self.zoomScale = zoomScale
        self.appliesOuterPadding = appliesOuterPadding
        self.style = style
        self.contentAlignment = contentAlignment
    }

    private var blocks: [NodeMarkdownBlock] {
        NodeMarkdownBlockParser.parse(text)
    }

    var body: some View {
        let scale = CGFloat(zoomScale)
        let contentInset = style.outerPadding * scale
        let contentWidth = max((CGFloat(nodeWidth) * scale) - (contentInset * 2), 1)

        VStack(alignment: contentAlignment.horizontalAlignment, spacing: style.markdownBlockSpacing * scale) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block, scale: scale)
            }
        }
        .frame(width: contentWidth, alignment: contentAlignment.frameAlignment)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment.frameAlignment)
        .padding(appliesOuterPadding ? contentInset : 0)
    }

    @ViewBuilder
    private func blockView(_ block: NodeMarkdownBlock, scale: CGFloat) -> some View {
        switch block {
        case .paragraph(let text):
            inlineMarkdownText(text)
                .font(.system(size: style.fontSize * scale, weight: style.displayFontWeight))
                .lineSpacing(style.markdownLineSpacing * scale)
                .multilineTextAlignment(contentAlignment.textAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: contentAlignment.frameAlignment)
        case .heading(let level, let text):
            inlineMarkdownText(text)
                .font(.system(size: headingFontSize(level: level, scale: scale), weight: .bold))
                .lineSpacing(style.markdownLineSpacing * scale)
                .multilineTextAlignment(contentAlignment.textAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: contentAlignment.frameAlignment)
        case .unorderedListItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: style.markdownListMarkerSpacing * scale) {
                Text("\u{2022}")
                    .font(.system(size: style.fontSize * scale, weight: .bold))
                inlineMarkdownText(text)
                    .font(.system(size: style.fontSize * scale, weight: style.displayFontWeight))
                    .lineSpacing(style.markdownLineSpacing * scale)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: contentAlignment.frameAlignment)
        case .orderedListItem(let marker, let text):
            HStack(alignment: .firstTextBaseline, spacing: style.markdownListMarkerSpacing * scale) {
                Text(marker)
                    .font(.system(size: style.fontSize * scale, weight: .semibold))
                inlineMarkdownText(text)
                    .font(.system(size: style.fontSize * scale, weight: style.displayFontWeight))
                    .lineSpacing(style.markdownLineSpacing * scale)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: contentAlignment.frameAlignment)
        case .codeBlock(let code):
            codeBlockView(code: code, scale: scale)
        }
    }

    private func codeBlockView(code: String, scale: CGFloat) -> some View {
        let accent = Color.accentColor
        return Text(code)
            .font(
                .system(
                    size: style.markdownCodeFontSize * scale,
                    weight: .regular,
                    design: .monospaced
                )
            )
            .foregroundStyle(accent.opacity(style.markdownCodeTextOpacity))
            .lineSpacing(style.markdownLineSpacing * scale)
            .frame(maxWidth: .infinity, alignment: contentAlignment.frameAlignment)
            .padding(style.markdownCodeBlockPadding * scale)
            .background(
                RoundedRectangle(cornerRadius: style.markdownCodeBlockCornerRadius * scale)
                    .fill(accent.opacity(style.markdownCodeBlockOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: style.markdownCodeBlockCornerRadius * scale)
                    .stroke(
                        accent.opacity(style.markdownCodeBorderOpacity),
                        lineWidth: style.markdownCodeBorderLineWidth * scale
                    )
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent.opacity(style.markdownCodeLeadingBarOpacity))
                    .frame(width: style.markdownCodeLeadingBarWidth * scale)
                    .clipShape(
                        RoundedRectangle(cornerRadius: style.markdownCodeBlockCornerRadius * scale)
                    )
            }
            .fixedSize(horizontal: false, vertical: true)
    }

    private func headingFontSize(level: Int, scale: CGFloat) -> CGFloat {
        let base = style.fontSize
        let multiplier: CGFloat
        switch level {
        case 1:
            multiplier = 1.5
        case 2:
            multiplier = 1.35
        case 3:
            multiplier = 1.2
        case 4:
            multiplier = 1.1
        default:
            multiplier = 1.0
        }
        return base * multiplier * scale
    }

    private func inlineMarkdownText(_ value: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard let attributed = try? AttributedString(markdown: value, options: options) else {
            return Text(value)
        }
        return Text(attributed)
    }
}

private enum NodeMarkdownBlock: Equatable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case unorderedListItem(String)
    case orderedListItem(marker: String, text: String)
    case codeBlock(String)
}

private enum NodeMarkdownBlockParser {
    static func parse(_ input: String) -> [NodeMarkdownBlock] {
        guard !input.isEmpty else {
            return [.paragraph("")]
        }

        var state = ParseState()
        for line in input.components(separatedBy: .newlines) {
            consume(line: line, state: &state)
        }
        return state.finalizedBlocks()
    }

    private static func consume(line: String, state: inout ParseState) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let fenceMarker = codeFenceMarker(from: trimmed) {
            state.flushParagraph()
            if let activeFenceMarker = state.activeCodeFenceMarker {
                if activeFenceMarker == fenceMarker {
                    state.flushCodeBlock()
                    state.activeCodeFenceMarker = nil
                } else {
                    state.codeLines.append(line)
                }
            } else {
                state.codeLines.removeAll(keepingCapacity: true)
                state.activeCodeFenceMarker = fenceMarker
            }
            return
        }

        if state.activeCodeFenceMarker != nil {
            state.codeLines.append(line)
            return
        }

        if let block = headingBlock(from: line) ?? unorderedListItemBlock(from: line)
            ?? orderedListItemBlock(from: line)
        {
            state.flushParagraph()
            state.blocks.append(block)
            return
        }

        if trimmed.isEmpty {
            state.flushParagraph()
            return
        }
        state.paragraphLines.append(line)
    }

    private static func headingBlock(from line: String) -> NodeMarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let level = trimmed.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else {
            return nil
        }
        let remaining = trimmed.dropFirst(level)
        guard remaining.first == " " else {
            return nil
        }
        let content = remaining.drop(while: { $0 == " " })
        return .heading(level: level, text: String(content))
    }

    private static func unorderedListItemBlock(from line: String) -> NodeMarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 2 else {
            return nil
        }
        let prefix = trimmed.prefix(2)
        guard prefix == "- " || prefix == "* " || prefix == "+ " else {
            return nil
        }
        return .unorderedListItem(String(trimmed.dropFirst(2)))
    }

    private static func orderedListItemBlock(from line: String) -> NodeMarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let markerEndIndex = trimmed.firstIndex(of: ".") else {
            return nil
        }
        let marker = trimmed[..<markerEndIndex]
        guard !marker.isEmpty else {
            return nil
        }
        guard marker.allSatisfy(\.isNumber) else {
            return nil
        }
        let nextIndex = trimmed.index(after: markerEndIndex)
        guard nextIndex < trimmed.endIndex, trimmed[nextIndex] == " " else {
            return nil
        }
        let contentStart = trimmed.index(after: nextIndex)
        let content = String(trimmed[contentStart...])
        return .orderedListItem(marker: "\(marker).", text: content)
    }

    private static func codeFenceMarker(from trimmed: String) -> CodeFenceMarker? {
        if trimmed.hasPrefix("```") {
            return .backtick
        }
        if trimmed.hasPrefix("~~~") {
            return .tilde
        }
        return nil
    }

    private struct ParseState {
        var blocks: [NodeMarkdownBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var activeCodeFenceMarker: CodeFenceMarker?

        mutating func flushParagraph() {
            guard !paragraphLines.isEmpty else {
                return
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
            paragraphLines.removeAll(keepingCapacity: true)
        }

        mutating func flushCodeBlock() {
            guard !codeLines.isEmpty else {
                blocks.append(.codeBlock(""))
                return
            }
            blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
            codeLines.removeAll(keepingCapacity: true)
        }

        mutating func finalizedBlocks() -> [NodeMarkdownBlock] {
            if activeCodeFenceMarker != nil {
                flushCodeBlock()
            }
            flushParagraph()
            return blocks.isEmpty ? [.paragraph("")] : blocks
        }
    }

    private enum CodeFenceMarker {
        case backtick
        case tilde
    }
}
