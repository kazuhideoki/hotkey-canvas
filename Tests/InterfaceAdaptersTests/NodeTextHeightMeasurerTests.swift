import CoreGraphics
import Testing

@testable import InterfaceAdapters

@Test("NodeTextHeightMeasurer: multiline text yields taller node than single line")
func test_measure_multilineText_isTallerThanSingleLine() {
    let sut = NodeTextHeightMeasurer()

    let singleLine = sut.measure(text: "hoge", nodeWidth: 220)
    let multiline = sut.measure(text: "hoge\n\n\n", nodeWidth: 220)

    #expect(multiline > singleLine)
}

@Test("NodeTextHeightMeasurer: narrow width increases wrapped text height")
func test_measure_narrowWidth_wrapsAndIncreasesHeight() {
    let sut = NodeTextHeightMeasurer()
    let text = "This is a long sentence to verify wrapping behavior."

    let wideHeight = sut.measure(text: text, nodeWidth: 260)
    let narrowHeight = sut.measure(text: text, nodeWidth: 120)

    #expect(narrowHeight > wideHeight)
}

@Test("NodeTextHeightMeasurer: empty text keeps minimum one-line height")
func test_measure_emptyText_keepsMinimumHeight() {
    let sut = NodeTextHeightMeasurer()

    let height = sut.measure(text: "", nodeWidth: 220)

    #expect(height >= 30)
}

@Test("NodeTextHeightMeasurer: empty one-line and text one-line use same height")
func test_measure_emptyAndSingleLineText_matchHeight() {
    let sut = NodeTextHeightMeasurer()

    let emptyHeight = sut.measure(text: "", nodeWidth: 220)
    let textHeight = sut.measure(text: "abc", nodeWidth: 220)

    #expect(abs(emptyHeight - textHeight) <= 0.5)
}

@Test("NodeTextHeightMeasurer: long text is capped by maximum height")
func test_measure_longText_isClampedToMaximumHeight() {
    let sut = NodeTextHeightMeasurer(maximumNodeHeight: 140)
    let text = String(repeating: "line\n", count: 60)

    let height = sut.measure(text: text, nodeWidth: 220)

    #expect(height == 140)
}

@Test("NodeTextHeightMeasurer: explicit newline increases rendered line count")
func test_measureLayout_explicitNewline_reportsMultipleLines() {
    let sut = NodeTextHeightMeasurer()

    let oneLine = sut.measureLayout(text: "abc", nodeWidth: 220)
    let twoLines = sut.measureLayout(text: "abc\ndef", nodeWidth: 220)

    #expect(twoLines.renderedLineCount > oneLine.renderedLineCount)
}

@Test("NodeTextHeightMeasurer: narrow width increases rendered line count by wrapping")
func test_measureLayout_narrowWidth_reportsMoreWrappedLines() {
    let sut = NodeTextHeightMeasurer()
    let text = "This is a long sentence to verify wrapped line counting behavior."

    let wideMetrics = sut.measureLayout(text: text, nodeWidth: 260)
    let narrowMetrics = sut.measureLayout(text: text, nodeWidth: 120)

    #expect(narrowMetrics.renderedLineCount > wideMetrics.renderedLineCount)
}
