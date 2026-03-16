// Background: Window-level canvas separation requires explicit session lifecycle management.
// Responsibility: Verify CanvasSessionStore creates isolated sessions and manages lifecycle metadata.
import Application
import Domain
import Testing

@MainActor
@Test("openSession はセッションごとに分離されたグラフ状態を作成する")
func test_openSession_createsIsolatedGraphState_perSession() async throws {
    let sut = CanvasSessionStore()
    let firstSession = sut.openSession()
    let secondSession = sut.openSession()

    _ = try await firstSession.inputPort.apply(commands: [.addNode])

    let firstGraph = await firstSession.inputPort.getCurrentGraph()
    let secondGraph = await secondSession.inputPort.getCurrentGraph()

    #expect(firstGraph.nodesByID.count == 1)
    #expect(secondGraph.nodesByID.isEmpty)
}

@MainActor
@Test("closeSession はアクティブなセッションをストアから削除する")
func test_closeSession_removesActiveSession_fromStore() {
    let sut = CanvasSessionStore()
    let session = sut.openSession()

    #expect(sut.sessionCount == 1)
    #expect(sut.inputPort(for: session.session.id) != nil)

    let removed = sut.closeSession(id: session.session.id)

    #expect(removed)
    #expect(sut.sessionCount == 0)
    #expect(sut.inputPort(for: session.session.id) == nil)
}
