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

@Test("NodeTextHeightMeasurer: long text is capped by maximum height")
func test_measure_longText_isClampedToMaximumHeight() {
    let sut = NodeTextHeightMeasurer(maximumNodeHeight: 140)
    let text = String(repeating: "line\n", count: 60)

    let height = sut.measure(text: text, nodeWidth: 220)

    #expect(height == 140)
}
