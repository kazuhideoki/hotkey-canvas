// Background: Node inline editing needs AppKit key handling not exposed by SwiftUI text components.
// Responsibility: Provide an NSTextView bridge with Enter commit, Escape cancel, and Option+Enter newline behavior.
import AppKit
import SwiftUI

/// Initial cursor position when the inline editor first receives focus.
enum NodeTextEditorInitialCursorPlacement: Equatable {
    case start
    case end
}

/// Inline editor used for canvas node text editing.
struct NodeTextEditor: NSViewRepresentable {
    @Binding var text: String
    let nodeWidth: CGFloat
    let zoomScale: Double
    let contentAlignment: NodeTextContentAlignment
    let selectAllOnFirstFocus: Bool
    let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
    let initialTypingEvent: NSEvent?
    let onLayoutMetricsChange: (NodeTextLayoutMetrics) -> Void
    let onCommit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NodeTextEditorTextView {
        let textView = NodeTextEditorTextView()
        textView.delegate = context.coordinator
        textView.onCommit = onCommit
        textView.onCancel = onCancel
        configureTextViewAppearance(
            textView,
            zoomScale: zoomScale,
            contentAlignment: contentAlignment
        )
        return textView
    }

    func updateNSView(_ nsView: NodeTextEditorTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
        context.coordinator.nodeWidth = nodeWidth
        context.coordinator.zoomScale = zoomScale
        nsView.onCommit = onCommit
        nsView.onCancel = onCancel
        configureTextViewAppearance(
            nsView,
            zoomScale: zoomScale,
            contentAlignment: contentAlignment
        )
        nsView.textColor = .labelColor
        nsView.insertionPointColor = .labelColor
        nsView.applyContentLayout()
        context.coordinator.pendingTypingEvent = initialTypingEvent
        context.coordinator.pushLayoutMetrics(for: nsView.string)
        focusEditorIfNeeded(nsView, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            nodeWidth: nodeWidth,
            zoomScale: zoomScale,
            selectAllOnFirstFocus: selectAllOnFirstFocus,
            initialCursorPlacement: initialCursorPlacement,
            initialTypingEvent: initialTypingEvent,
            onLayoutMetricsChange: onLayoutMetricsChange
        )
    }
}

extension NodeTextEditor {
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var nodeWidth: CGFloat
        var zoomScale: Double
        let selectAllOnFirstFocus: Bool
        let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
        var pendingTypingEvent: NSEvent?
        var lastReplayedTypingEventTimestamp: TimeInterval = -1
        let onLayoutMetricsChange: (NodeTextLayoutMetrics) -> Void
        let nodeTextHeightMeasurer = NodeTextHeightMeasurer()
        var hasFocusedEditor: Bool = false
        /// Monotonic token used to cancel stale focus retries from older update cycles.
        var focusRequestID: UInt64 = 0

        init(
            text: Binding<String>,
            nodeWidth: CGFloat,
            zoomScale: Double,
            selectAllOnFirstFocus: Bool,
            initialCursorPlacement: NodeTextEditorInitialCursorPlacement,
            initialTypingEvent: NSEvent?,
            onLayoutMetricsChange: @escaping (NodeTextLayoutMetrics) -> Void
        ) {
            self.text = text
            self.nodeWidth = nodeWidth
            self.zoomScale = zoomScale
            self.selectAllOnFirstFocus = selectAllOnFirstFocus
            self.initialCursorPlacement = initialCursorPlacement
            self.pendingTypingEvent = initialTypingEvent
            self.onLayoutMetricsChange = onLayoutMetricsChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            text.wrappedValue = textView.string
            pushLayoutMetrics(for: textView.string)
        }

        func pushLayoutMetrics(for text: String) {
            let metrics = nodeTextHeightMeasurer.measureLayout(
                text: text,
                nodeWidth: nodeWidth
            )
            onLayoutMetricsChange(metrics)
        }
    }

    private func configureTextViewAppearance(
        _ textView: NodeTextEditorTextView,
        zoomScale: Double,
        contentAlignment: NodeTextContentAlignment
    ) {
        let clampedZoomScale = max(CGFloat(zoomScale), 0.0001)
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = .systemFont(
            ofSize: NodeTextStyle.fontSize * clampedZoomScale,
            weight: NodeTextStyle.fontWeight
        )
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = contentAlignment == .topLeading
        textView.baseTextContainerInset = NodeTextStyle.textContainerInset * clampedZoomScale
        textView.nodeTextContentAlignment = contentAlignment
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: 1,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.typingAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: textView.font ?? NodeTextStyle.font,
        ]
        textView.applyContentLayout()
    }

    private func focusEditorIfNeeded(
        _ textView: NodeTextEditorTextView,
        coordinator: Coordinator
    ) {
        // Cancel outstanding retries and start a new focus cycle for the latest editor state.
        coordinator.focusRequestID &+= 1
        let requestID = coordinator.focusRequestID
        attemptFocus(
            textView,
            coordinator: coordinator,
            requestID: requestID,
            remainingAttempts: 20
        )
    }

    private func attemptFocus(
        _ textView: NodeTextEditorTextView,
        coordinator: Coordinator,
        requestID: UInt64,
        remainingAttempts: Int
    ) {
        // Retry with a short delay because first responder handoff can race with SwiftUI view updates.
        let delay: DispatchTimeInterval = remainingAttempts == 20 ? .milliseconds(0) : .milliseconds(10)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard coordinator.focusRequestID == requestID else {
                return
            }
            guard let window = textView.window else {
                guard remainingAttempts > 1 else {
                    return
                }
                attemptFocus(
                    textView,
                    coordinator: coordinator,
                    requestID: requestID,
                    remainingAttempts: remainingAttempts - 1
                )
                return
            }

            guard window.firstResponder !== textView else {
                self.replayPendingTypingEventIfNeeded(
                    textView,
                    coordinator: coordinator
                )
                coordinator.hasFocusedEditor = true
                return
            }

            let becameFirstResponder = window.makeFirstResponder(textView)
            guard becameFirstResponder else {
                guard remainingAttempts > 1 else {
                    return
                }
                attemptFocus(
                    textView,
                    coordinator: coordinator,
                    requestID: requestID,
                    remainingAttempts: remainingAttempts - 1
                )
                return
            }

            if coordinator.selectAllOnFirstFocus, !coordinator.hasFocusedEditor {
                textView.selectAll(nil)
            } else if !coordinator.hasFocusedEditor {
                placeInitialCursor(textView, placement: coordinator.initialCursorPlacement)
            }
            self.replayPendingTypingEventIfNeeded(
                textView,
                coordinator: coordinator
            )
            coordinator.hasFocusedEditor = true
        }
    }

    private func replayPendingTypingEventIfNeeded(
        _ textView: NodeTextEditorTextView,
        coordinator: Coordinator
    ) {
        guard let event = coordinator.pendingTypingEvent else {
            return
        }
        guard coordinator.lastReplayedTypingEventTimestamp != event.timestamp else {
            return
        }
        textView.interpretKeyEvents([event])
        coordinator.lastReplayedTypingEventTimestamp = event.timestamp
    }

    private func placeInitialCursor(
        _ textView: NodeTextEditorTextView,
        placement: NodeTextEditorInitialCursorPlacement
    ) {
        let textLength = (textView.string as NSString).length
        let location: Int
        switch placement {
        case .start:
            location = 0
        case .end:
            location = textLength
        }
        textView.setSelectedRange(NSRange(location: location, length: 0))
    }
}

/// NSTextView subclass that commits with Enter, cancels with Escape, and inserts newline with Option+Enter.
class NodeTextEditorTextView: NSTextView {
    private static let enterKeyCode: UInt16 = 36
    private static let escapeKeyCode: UInt16 = 53

    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var baseTextContainerInset: CGFloat = NodeTextStyle.textContainerInset {
        didSet {
            applyContentLayout()
        }
    }
    var nodeTextContentAlignment: NodeTextContentAlignment = .topLeading {
        didSet {
            applyContentLayout()
        }
    }

    override func didChangeText() {
        super.didChangeText()
        applyContentLayout()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        applyContentLayout()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            // During IME composition, Escape must cancel marked text in NSTextView.
            guard !hasMarkedText() else {
                super.keyDown(with: event)
                return
            }
            onCancel?()
            return
        }

        guard event.keyCode == Self.enterKeyCode else {
            super.keyDown(with: event)
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // During IME composition, Enter must confirm marked text in NSTextView.
        guard !hasMarkedText() else {
            let disallowed: NSEvent.ModifierFlags = [.control, .option, .shift, .function]
            if flags.contains(.command), flags.isDisjoint(with: disallowed) {
                unmarkText()
                onCommit?()
                return
            }
            super.keyDown(with: event)
            return
        }

        if flags.contains(.option), flags.isDisjoint(with: [.command, .control]) {
            insertNewline(nil)
            return
        }

        let disallowed: NSEvent.ModifierFlags = [.control, .option, .shift, .function]
        if flags.isDisjoint(with: disallowed) {
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }

    func applyContentLayout() {
        applyTextContainerSize()
        let paragraphAlignment = nodeTextContentAlignment.paragraphAlignment
        applyParagraphAlignment(paragraphAlignment)
        let contentHeight = measuredTextContentHeight()
        let verticalInset = Self.verticalInset(
            boundsHeight: bounds.height,
            contentHeight: contentHeight,
            baseInset: baseTextContainerInset,
            contentAlignment: nodeTextContentAlignment
        )
        let nextInset = NSSize(width: baseTextContainerInset, height: verticalInset)
        if textContainerInset != nextInset {
            textContainerInset = nextInset
        }
    }

    static func verticalInset(
        boundsHeight: CGFloat,
        contentHeight: CGFloat,
        baseInset: CGFloat,
        contentAlignment: NodeTextContentAlignment
    ) -> CGFloat {
        let clampedBaseInset = max(baseInset, 0)
        guard boundsHeight.isFinite, contentHeight.isFinite else {
            return clampedBaseInset
        }
        switch contentAlignment {
        case .topLeading:
            return clampedBaseInset
        case .center:
            return max((boundsHeight - contentHeight) / 2, clampedBaseInset)
        }
    }
}

extension NodeTextEditorTextView {
    private func applyTextContainerSize() {
        guard let textContainer else {
            return
        }
        let clampedInset = max(baseTextContainerInset, 0)
        let targetWidth = max(bounds.width - (clampedInset * 2), 1)
        let targetSize = NSSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
        if textContainer.widthTracksTextView {
            textContainer.widthTracksTextView = false
        }
        if textContainer.containerSize != targetSize {
            textContainer.containerSize = targetSize
        }
    }

    private func applyParagraphAlignment(_ alignment: NSTextAlignment) {
        if self.alignment != alignment {
            self.alignment = alignment
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        var attributes = typingAttributes
        attributes[.paragraphStyle] = paragraphStyle
        attributes[.foregroundColor] = textColor ?? NSColor.labelColor
        attributes[.font] = font ?? NodeTextStyle.font
        typingAttributes = attributes
        let textLength = (string as NSString).length
        guard textLength > 0 else {
            return
        }
        setAlignment(alignment, range: NSRange(location: 0, length: textLength))
    }

    private func measuredTextContentHeight() -> CGFloat {
        guard let layoutManager, let textContainer else {
            return NSLayoutManager().defaultLineHeight(for: font ?? NodeTextStyle.font)
        }
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.ensureLayout(forGlyphRange: glyphRange)
        let usedHeight = layoutManager.usedRect(for: textContainer).height
        let defaultLineHeight = layoutManager.defaultLineHeight(for: font ?? NodeTextStyle.font)
        return max(ceil(usedHeight), defaultLineHeight)
    }
}
