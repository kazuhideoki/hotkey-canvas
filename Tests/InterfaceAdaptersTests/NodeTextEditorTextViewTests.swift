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

@Test("先頭から始まる段落の配置はロケールを認識する")
func test_nodeTextContentAlignment_topLeadingParagraphAlignment_isNatural() {
    #expect(NodeTextContentAlignment.topLeading.paragraphAlignment == .natural)
}

@Test("段落の中央揃えは中央揃えのまま")
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

@Test("Enter で編集を確定する")
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

@Test("Command+Enter は編集をコミットする")
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

@Test("IME コンポジションがアクティブなときに Command+Enter が編集をコミットする")
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

@Test("エスケープすると編集がキャンセルされる")
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

@Test("中央揃えは、テキストを中央に配置する垂直方向の差し込みを計算する")
func test_verticalInset_centerAlignment_centersText() {
    let inset = NodeTextEditorTextView.verticalInset(
        boundsHeight: 200,
        contentHeight: 40,
        baseInset: 6,
        contentAlignment: .center
    )

    #expect(inset == 80)
}

@Test("コンテンツがオーバーフローしても、中央揃えによりベースのインセットが維持される")
func test_verticalInset_centerAlignment_overflowKeepsBaseInset() {
    let inset = NodeTextEditorTextView.verticalInset(
        boundsHeight: 48,
        contentHeight: 80,
        baseInset: 6,
        contentAlignment: .center
    )

    #expect(inset == 6)
}

@Test("先頭の配置では常にベース インセットが使用される")
func test_verticalInset_topLeadingAlignment_usesBaseInset() {
    let inset = NodeTextEditorTextView.verticalInset(
        boundsHeight: 200,
        contentHeight: 40,
        baseInset: 6,
        contentAlignment: .topLeading
    )

    #expect(inset == 6)
}

@Test("中央揃え テキストを水平方向に中央揃えにする")
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

@Test("先頭の配置により、テキストが先頭の差し込み口の近くに配置される")
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
