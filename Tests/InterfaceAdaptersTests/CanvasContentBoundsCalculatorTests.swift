import Domain
import InterfaceAdapters
import Testing

@Test("CanvasContentBoundsCalculator: empty nodes return minimum area from origin")
func test_calculate_emptyNodes_returnsMinimumArea() {
    let result = CanvasContentBoundsCalculator.calculate(
        nodes: [],
        minimumWidth: 900,
        minimumHeight: 600,
        margin: 120
    )

    #expect(result.minX == 0)
    #expect(result.minY == 0)
    #expect(result.width == 900)
    #expect(result.height == 600)
}

@Test("CanvasContentBoundsCalculator: includes negative coordinates and margin")
func test_calculate_nodesWithNegativeCoordinates_expandsInAllDirections() {
    let nodes = [
        CanvasNode(
            id: CanvasNodeID(rawValue: "left-top"),
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: -200, y: -120, width: 100, height: 80)
        ),
        CanvasNode(
            id: CanvasNodeID(rawValue: "right-bottom"),
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 320, y: 260, width: 200, height: 100)
        )
    ]

    let result = CanvasContentBoundsCalculator.calculate(
        nodes: nodes,
        minimumWidth: 0,
        minimumHeight: 0,
        margin: 40
    )

    #expect(result.minX == -240)
    #expect(result.minY == -160)
    #expect(result.width == 800)
    #expect(result.height == 560)
}

@Test("CanvasContentBoundsCalculator: minimum area is centered around content bounds")
func test_calculate_smallContent_appliesMinimumAreaWithCenterPadding() {
    let nodes = [
        CanvasNode(
            id: CanvasNodeID(rawValue: "node-1"),
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 100, y: 140, width: 220, height: 120)
        )
    ]

    let result = CanvasContentBoundsCalculator.calculate(
        nodes: nodes,
        minimumWidth: 900,
        minimumHeight: 600,
        margin: 20
    )

    #expect(result.width == 900)
    #expect(result.height == 600)
    #expect(result.minX == -240)
    #expect(result.minY == -100)
}
