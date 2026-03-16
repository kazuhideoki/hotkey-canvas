import CoreGraphics
import Testing

@testable import InterfaceAdapters

@Test("複数行のテキストは単一行よりも高いノードを生成する")
func test_measure_multilineText_isTallerThanSingleLine() {
    let sut = NodeTextHeightMeasurer()

    let singleLine = sut.measure(text: "hoge", nodeWidth: 220)
    let multiline = sut.measure(text: "hoge\n\n\n", nodeWidth: 220)

    #expect(multiline > singleLine)
}

@Test("幅が狭いと折り返されたテキストの高さが大きくなる")
func test_measure_narrowWidth_wrapsAndIncreasesHeight() {
    let sut = NodeTextHeightMeasurer()
    let text = "This is a long sentence to verify wrapping behavior."

    let wideHeight = sut.measure(text: text, nodeWidth: 260)
    let narrowHeight = sut.measure(text: text, nodeWidth: 120)

    #expect(narrowHeight > wideHeight)
}

@Test("空のテキストは最小の 1 行の高さを維持する")
func test_measure_emptyText_keepsMinimumHeight() {
    let sut = NodeTextHeightMeasurer()

    let height = sut.measure(text: "", nodeWidth: 220)

    #expect(height >= 30)
}

@Test("空の 1 行とテキストの 1 行は同じ高さを使う")
func test_measure_emptyAndSingleLineText_matchHeight() {
    let sut = NodeTextHeightMeasurer()

    let emptyHeight = sut.measure(text: "", nodeWidth: 220)
    let textHeight = sut.measure(text: "abc", nodeWidth: 220)

    #expect(abs(emptyHeight - textHeight) <= 0.5)
}

@Test("長いテキストは最大高さで制限される")
func test_measure_longText_isClampedToMaximumHeight() {
    let sut = NodeTextHeightMeasurer(maximumNodeHeight: 140)
    let text = String(repeating: "line\n", count: 60)

    let height = sut.measure(text: text, nodeWidth: 220)

    #expect(height == 140)
}

@Test("デフォルト設定は従来の上限を超える可能性があります")
func test_measure_manyLines_exceedsLegacyCap() {
    let sut = NodeTextHeightMeasurer()
    let text = String(repeating: "line\n", count: 80)

    let height = sut.measure(text: text, nodeWidth: 220)

    #expect(height > 320)
}

@Test("コンテンツスケールは、同じテキストの測定された高さを増加させます")
func test_measure_contentScale_increasesMeasuredHeight() {
    let base = NodeTextHeightMeasurer()
    let scaled = NodeTextHeightMeasurer(style: .defaultStyle, contentScale: 1.5)
    let text = "scaled text"

    let baseHeight = base.measure(text: text, nodeWidth: 220)
    let scaledHeight = scaled.measure(text: text, nodeWidth: 220)

    #expect(scaledHeight > baseHeight)
}
