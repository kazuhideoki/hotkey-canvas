import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasSearchNavigator: matches are ordered top-to-bottom then left-to-right")
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

@Test("CanvasSearchNavigator: nextMatch loops forward and backward")
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

@Test("CanvasSearchNavigator: backward without current match starts from last")
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
