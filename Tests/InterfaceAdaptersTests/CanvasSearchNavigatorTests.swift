import Domain
import Testing

@testable import InterfaceAdapters

@Test("一致は上から下、次に左から右の順に並べられます")
func test_matches_ordersByNodePosition() {
    let topLeftID = CanvasNodeID(rawValue: "top-left")
    let topRightID = CanvasNodeID(rawValue: "top-right")
    let lowerID = CanvasNodeID(rawValue: "lower")
    let nodes: [CanvasNode] = [
        CanvasNode(
            id: lowerID,
            kind: .text,
            text: "find",
            bounds: CanvasBounds(x: 0, y: 200, width: 120, height: 60),
            markdownStyleEnabled: false
        ),
        CanvasNode(
            id: topRightID,
            kind: .text,
            text: "find",
            bounds: CanvasBounds(x: 200, y: 0, width: 120, height: 60),
            markdownStyleEnabled: false
        ),
        CanvasNode(
            id: topLeftID,
            kind: .text,
            text: "find",
            bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 60),
            markdownStyleEnabled: false
        ),
    ]

    let matches = CanvasSearchNavigator.matches(query: "find", nodes: nodes)

    #expect(matches.map(\.nodeID) == [topLeftID, topRightID, lowerID])
}

@Test("nextMatch は順方向と逆方向にループする")
func test_nextMatch_loopsInBothDirections() {
    let nodeA = CanvasNodeID(rawValue: "a")
    let nodeB = CanvasNodeID(rawValue: "b")
    let matches = [
        CanvasSearchMatch(nodeID: nodeA, location: 0, length: 1),
        CanvasSearchMatch(nodeID: nodeB, location: 0, length: 1),
    ]

    let forwardFromLast = CanvasSearchNavigator.nextMatch(
        currentMatch: matches[1],
        matches: matches,
        direction: .forward
    )
    let backwardFromFirst = CanvasSearchNavigator.nextMatch(
        currentMatch: matches[0],
        matches: matches,
        direction: .backward
    )

    #expect(forwardFromLast == matches[0])
    #expect(backwardFromFirst == matches[1])
}

@Test("現在の一致なしで後方に戻ると最後から開始される")
func test_nextMatch_backwardWithoutCurrent_startsFromLast() {
    let nodeA = CanvasNodeID(rawValue: "a")
    let nodeB = CanvasNodeID(rawValue: "b")
    let matches = [
        CanvasSearchMatch(nodeID: nodeA, location: 0, length: 1),
        CanvasSearchMatch(nodeID: nodeB, location: 3, length: 1),
    ]

    let selected = CanvasSearchNavigator.nextMatch(
        currentMatch: nil,
        matches: matches,
        direction: .backward
    )

    #expect(selected == matches[1])
}
