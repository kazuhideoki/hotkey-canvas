import AppKit
import Testing

@testable import InterfaceAdapters

private enum NodeTextEditorTextViewLayoutProbe {
    static func firstGlyphOriginX(in textView: NodeTextEditorTextView) -> CGFloat? {
        guard
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else {
            return nil
        }
        let textLength = (textView.string as NSString).length
        guard textLength > 0 else {
            return nil
        }
        layoutManager.ensureLayout(for: textContainer)
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: 0)
        var lineRange = NSRange(location: 0, length: 0)
        let lineFragmentRect = layoutManager.lineFragmentRect(
            forGlyphAt: glyphIndex,
            effectiveRange: &lineRange
        )
        let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
        return textView.textContainerOrigin.x + lineFragmentRect.minX + glyphLocation.x
    }
}

@Test("NodeTextContentAlignment: top-leading paragraph alignment is locale-aware")
func test_nodeTextContentAlignment_topLeadingParagraphAlignment_isNatural() {
    #expect(NodeTextContentAlignment.topLeading.paragraphAlignment == .natural)
}

@Test("NodeTextContentAlignment: center paragraph alignment remains center")
func test_nodeTextContentAlignment_centerParagraphAlignment_isCenter() {
    #expect(NodeTextContentAlignment.center.paragraphAlignment == .center)
}

private final class MarkedTextNodeTextEditorTextViewSpy: NodeTextEditorTextView {
    var markedText: Bool = true
    var unmarkTextCount: Int = 0

    override func hasMarkedText() -> Bool {
        markedText
    }

    override func unmarkText() {
        unmarkTextCount += 1
        markedText = false
    }
}

@Test("NodeTextEditorTextView: Enter commits editing")
func test_keyDown_enter_commitsEditing() throws {
    var commitCount = 0
    var cancelCount = 0
    let sut = NodeTextEditorTextView()
    sut.onCommit = { commitCount += 1 }
    sut.onCancel = { cancelCount += 1 }
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    sut.keyDown(with: event)

    #expect(commitCount == 1)
    #expect(cancelCount == 0)
}

@Test("NodeTextEditorTextView: Command+Enter commits editing")
func test_keyDown_commandEnter_commitsEditing() throws {
    var commitCount = 0
    var cancelCount = 0
    let sut = NodeTextEditorTextView()
    sut.onCommit = { commitCount += 1 }
    sut.onCancel = { cancelCount += 1 }
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    sut.keyDown(with: event)

    #expect(commitCount == 1)
    #expect(cancelCount == 0)
}

@Test("NodeTextEditorTextView: Command+Enter commits editing while IME composition is active")
func test_keyDown_commandEnter_withMarkedText_confirmsImeAndCommitsEditing() throws {
    var commitCount = 0
    var cancelCount = 0
    let sut = MarkedTextNodeTextEditorTextViewSpy()
    sut.onCommit = { commitCount += 1 }
    sut.onCancel = { cancelCount += 1 }
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    sut.keyDown(with: event)

    #expect(sut.unmarkTextCount == 1)
    #expect(commitCount == 1)
    #expect(cancelCount == 0)
}

@Test("NodeTextEditorTextView: Escape cancels editing")
func test_keyDown_escape_cancelsEditing() throws {
    var commitCount = 0
    var cancelCount = 0
    let sut = NodeTextEditorTextView()
    sut.onCommit = { commitCount += 1 }
    sut.onCancel = { cancelCount += 1 }
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53
        )
    )

    sut.keyDown(with: event)

    #expect(commitCount == 0)
    #expect(cancelCount == 1)
}

@Test("NodeTextEditorTextView: center alignment computes vertical inset to center text")
func test_verticalInset_centerAlignment_centersText() {
    let inset = NodeTextEditorTextView.verticalInset(
        boundsHeight: 200,
        contentHeight: 40,
        baseInset: 6,
        contentAlignment: .center
    )

    #expect(inset == 80)
}

@Test("NodeTextEditorTextView: center alignment keeps base inset when content overflows")
func test_verticalInset_centerAlignment_overflowKeepsBaseInset() {
    let inset = NodeTextEditorTextView.verticalInset(
        boundsHeight: 48,
        contentHeight: 80,
        baseInset: 6,
        contentAlignment: .center
    )

    #expect(inset == 6)
}

@Test("NodeTextEditorTextView: top-leading alignment always uses base inset")
func test_verticalInset_topLeadingAlignment_usesBaseInset() {
    let inset = NodeTextEditorTextView.verticalInset(
        boundsHeight: 200,
        contentHeight: 40,
        baseInset: 6,
        contentAlignment: .topLeading
    )

    #expect(inset == 6)
}

@Test("NodeTextEditorTextView: center alignment centers text horizontally")
@MainActor
func test_applyContentLayout_centerAlignment_centersTextHorizontally() throws {
    let sut = NodeTextEditorTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 120))
    sut.font = NodeTextStyle.font
    sut.baseTextContainerInset = 6
    sut.nodeTextContentAlignment = .center
    sut.string = "input"
    sut.applyContentLayout()

    let firstGlyphOriginX = try #require(NodeTextEditorTextViewLayoutProbe.firstGlyphOriginX(in: sut))
    #expect(firstGlyphOriginX > 30)
}

@Test("NodeTextEditorTextView: top-leading alignment keeps text near leading inset")
@MainActor
func test_applyContentLayout_topLeadingAlignment_keepsLeadingPosition() throws {
    let sut = NodeTextEditorTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 120))
    sut.font = NodeTextStyle.font
    sut.baseTextContainerInset = 6
    sut.nodeTextContentAlignment = .topLeading
    sut.string = "input"
    sut.applyContentLayout()

    let firstGlyphOriginX = try #require(NodeTextEditorTextViewLayoutProbe.firstGlyphOriginX(in: sut))
    #expect(firstGlyphOriginX < 20)
}
