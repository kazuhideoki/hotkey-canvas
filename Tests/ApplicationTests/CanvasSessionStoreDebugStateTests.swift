// Background: Debug state APIs must expose deterministic session-level snapshots for external tooling.
// Responsibility: Verify CanvasSessionStore debug-read contracts for active sessions.
import Application
import Domain
import Testing

@MainActor
@Test("CanvasSessionStore: activeSessionIDs returns sorted identifiers")
func test_activeSessionIDs_returnsSortedIdentifiers() {
    let sut = CanvasSessionStore()
    let first = sut.openSession()
    let second = sut.openSession()

    let expected = [first.session.id, second.session.id].sorted { $0.rawValue < $1.rawValue }

    #expect(sut.activeSessionIDs() == expected)
}

@MainActor
@Test("CanvasSessionStore: currentResultsBySessionID returns latest session snapshots")
func test_currentResultsBySessionID_returnsLatestSnapshots() async throws {
    let sut = CanvasSessionStore()
    let first = sut.openSession()
    let second = sut.openSession()

    _ = try await second.inputPort.apply(commands: [.addNode])

    let snapshots = await sut.currentResultsBySessionID()

    #expect(snapshots.keys.count == 2)
    #expect(snapshots[first.session.id]?.newState.nodesByID.isEmpty == true)
    #expect(snapshots[second.session.id]?.newState.nodesByID.count == 1)
}
