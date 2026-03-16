import Domain
import Testing

@Test("展開すると、長方形が両軸で均等に成長する")
func test_expanded_growsRectangle() {
    let rect = CanvasRect(minX: 10, minY: 20, width: 100, height: 80)

    let expanded = rect.expanded(horizontal: 8, vertical: 12)

    #expect(expanded.minX == 2)
    #expect(expanded.minY == 8)
    #expect(expanded.width == 116)
    #expect(expanded.height == 104)
}

@Test("負の展開はゼロとして扱われます")
func test_expanded_negativeValues_noChange() {
    let rect = CanvasRect(minX: 0, minY: 0, width: 40, height: 30)

    let expanded = rect.expanded(horizontal: -5, vertical: -7)

    #expect(expanded == rect)
}
