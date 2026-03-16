// 背景: Diagram node move は非凸な selected-node cluster の衝突解消を扱うようになった。
// 責務: concave gap を潰さずに矩形 union の衝突解消ができることを検証する。
import Domain
import Testing

@Test("CanvasCollisionResolutionService: rect union keeps blocker inside concave gap without collision")
func test_resolveOverlaps_rectUnion_keepsConcaveGapOpen() {
    let seedBody = CanvasCollisionBody(
        id: .cluster(nodeIDs: [
            CanvasNodeID(rawValue: "a"),
            CanvasNodeID(rawValue: "b"),
            CanvasNodeID(rawValue: "c"),
        ]),
        nodeIDs: [CanvasNodeID(rawValue: "a"), CanvasNodeID(rawValue: "b"), CanvasNodeID(rawValue: "c")],
        shape: CanvasCollisionShape(
            rects: [
                CanvasRect(minX: 0, minY: 0, width: 100, height: 300),
                CanvasRect(minX: 100, minY: 0, width: 200, height: 100),
                CanvasRect(minX: 100, minY: 200, width: 200, height: 100),
            ]
        )
    )
    let blockerBody = CanvasCollisionBody(
        id: .node(CanvasNodeID(rawValue: "blocker")),
        nodeIDs: [CanvasNodeID(rawValue: "blocker")],
        shape: CanvasCollisionShape(
            rect: CanvasRect(minX: 150, minY: 100, width: 100, height: 100)
        )
    )

    let translations = CanvasCollisionResolutionService.resolveOverlaps(
        bodies: [seedBody, blockerBody],
        seedBodyID: seedBody.id
    )

    #expect(translations.isEmpty)
}

@Test("CanvasCollisionResolutionService: rect union resolves overlap on one selected node")
func test_resolveOverlaps_rectUnion_resolvesOverlapOnOneMember() {
    let seedBody = CanvasCollisionBody(
        id: .cluster(nodeIDs: [
            CanvasNodeID(rawValue: "left"),
            CanvasNodeID(rawValue: "right"),
        ]),
        nodeIDs: [CanvasNodeID(rawValue: "left"), CanvasNodeID(rawValue: "right")],
        shape: CanvasCollisionShape(
            rects: [
                CanvasRect(minX: 0, minY: 0, width: 100, height: 100),
                CanvasRect(minX: 220, minY: 0, width: 100, height: 100),
            ]
        )
    )
    let blockerBody = CanvasCollisionBody(
        id: .node(CanvasNodeID(rawValue: "blocker")),
        nodeIDs: [CanvasNodeID(rawValue: "blocker")],
        shape: CanvasCollisionShape(
            rect: CanvasRect(minX: 260, minY: 0, width: 100, height: 100)
        )
    )

    let translations = CanvasCollisionResolutionService.resolveOverlaps(
        bodies: [seedBody, blockerBody],
        seedBodyID: seedBody.id
    )

    let selectionTranslation = translations[seedBody.id] ?? .zero
    let blockerTranslation = translations[blockerBody.id] ?? .zero
    expectAlmostEqual(selectionTranslation.dx, -30)
    expectAlmostEqual(selectionTranslation.dy, 0)
    expectAlmostEqual(blockerTranslation.dx, 30)
    expectAlmostEqual(blockerTranslation.dy, 0)
}

@Test("CanvasCollisionResolutionService: preferred seed direction keeps seed slot and pushes blocker along command axis")
func test_resolveOverlaps_withPreferredSeedDirection_preservesSeedSlot() {
    let seedBody = CanvasCollisionBody(
        id: .cluster(nodeIDs: [
            CanvasNodeID(rawValue: "focused"),
            CanvasNodeID(rawValue: "selected"),
        ]),
        nodeIDs: [CanvasNodeID(rawValue: "focused"), CanvasNodeID(rawValue: "selected")],
        shape: CanvasCollisionShape(
            rects: [
                CanvasRect(minX: 440, minY: 440, width: 220, height: 220),
                CanvasRect(minX: 880, minY: 440, width: 220, height: 220),
            ]
        )
    )
    let blockerBody = CanvasCollisionBody(
        id: .node(CanvasNodeID(rawValue: "blocker")),
        nodeIDs: [CanvasNodeID(rawValue: "blocker")],
        shape: CanvasCollisionShape(
            rect: CanvasRect(minX: 880, minY: 440, width: 220, height: 220)
        )
    )

    let translations = CanvasCollisionResolutionService.resolveOverlaps(
        bodies: [seedBody, blockerBody],
        seedBodyID: seedBody.id,
        minimumSpacing: 16,
        seedPreferredMoveDirection: .down
    )

    #expect(translations[seedBody.id] == nil)
    let blockerTranslation = translations[blockerBody.id] ?? .zero
    expectAlmostEqual(blockerTranslation.dx, 0)
    expectAlmostEqual(blockerTranslation.dy, 236)
}

@Test("CanvasCollisionResolutionService: missing seed or disabled iteration returns no translation")
func test_resolveOverlaps_missingSeedOrDisabledIteration_returnsEmpty() {
    let bodyA = makeCollisionBody(id: "a", minX: 0, minY: 0, width: 100, height: 100)
    let bodyB = makeCollisionBody(id: "b", minX: 80, minY: 0, width: 100, height: 100)

    let missingSeedTranslations = CanvasCollisionResolutionService.resolveOverlaps(
        bodies: [bodyA, bodyB],
        seedBodyID: .node(CanvasNodeID(rawValue: "missing"))
    )
    let disabledIterationTranslations = CanvasCollisionResolutionService.resolveOverlaps(
        bodies: [bodyA, bodyB],
        seedBodyID: bodyA.id,
        maxIterations: 0
    )

    #expect(missingSeedTranslations.isEmpty)
    #expect(disabledIterationTranslations.isEmpty)
}

@Test("CanvasCollisionResolutionService: vertical overlap moves bodies on Y axis")
func test_resolveOverlaps_verticalOverlap_movesBodiesOnYAxis() {
    let lowerBody = makeCollisionBody(id: "lower", minX: 0, minY: 100, width: 100, height: 100)
    let upperBody = makeCollisionBody(id: "upper", minX: 0, minY: 40, width: 100, height: 100)

    let translations = CanvasCollisionResolutionService.resolveOverlaps(
        bodies: [lowerBody, upperBody],
        seedBodyID: lowerBody.id
    )

    let lowerTranslation = translations[lowerBody.id] ?? .zero
    let upperTranslation = translations[upperBody.id] ?? .zero
    expectAlmostEqual(lowerTranslation.dx, 0)
    expectAlmostEqual(lowerTranslation.dy, 20)
    expectAlmostEqual(upperTranslation.dx, 0)
    expectAlmostEqual(upperTranslation.dy, -20)
}

@Test("CanvasCollisionResolutionService: minimum spacing increases resolved distance")
func test_resolveOverlaps_withMinimumSpacing_increasesResolvedDistance() {
    let bodyA = makeCollisionBody(id: "a", minX: 0, minY: 0, width: 100, height: 100)
    let bodyB = makeCollisionBody(id: "b", minX: 80, minY: 0, width: 100, height: 100)

    let translations = CanvasCollisionResolutionService.resolveOverlaps(
        bodies: [bodyA, bodyB],
        seedBodyID: bodyA.id,
        minimumSpacing: 20
    )

    let translationA = translations[bodyA.id] ?? .zero
    let translationB = translations[bodyB.id] ?? .zero
    expectAlmostEqual(translationA.dx, -20)
    expectAlmostEqual(translationA.dy, 0)
    expectAlmostEqual(translationB.dx, 20)
    expectAlmostEqual(translationB.dy, 0)
}

@Test("CanvasCollisionResolutionService: node body ID does not collide with cluster body ID")
func test_resolveOverlaps_nodeBodyIDDoesNotCollideWithClusterBodyID() {
    let sharedRawValue = CanvasNodeID(rawValue: "diagram-selection:selected,other")
    let clusterBody = CanvasCollisionBody(
        id: .cluster(nodeIDs: [CanvasNodeID(rawValue: "other"), CanvasNodeID(rawValue: "selected")]),
        nodeIDs: [CanvasNodeID(rawValue: "other"), CanvasNodeID(rawValue: "selected")],
        shape: CanvasCollisionShape(
            rects: [
                CanvasRect(minX: 0, minY: 0, width: 100, height: 100),
                CanvasRect(minX: 120, minY: 0, width: 100, height: 100),
            ]
        )
    )
    let nodeBody = CanvasCollisionBody(
        id: .node(sharedRawValue),
        nodeIDs: [sharedRawValue],
        shape: CanvasCollisionShape(
            rect: CanvasRect(minX: 120, minY: 0, width: 100, height: 100)
        )
    )

    let translations = CanvasCollisionResolutionService.resolveOverlaps(
        bodies: [clusterBody, nodeBody],
        seedBodyID: clusterBody.id
    )

    #expect(translations.isEmpty == false)
}

@Test("CanvasCollisionResolutionService: propagated collision moves encountered third body")
func test_resolveOverlaps_chainCollision_movesEncounteredThirdBody() {
    let seedBody = makeCollisionBody(id: "seed", minX: 0, minY: 0, width: 100, height: 100)
    let middleBody = makeCollisionBody(id: "middle", minX: 80, minY: 0, width: 100, height: 100)
    let tailBody = makeCollisionBody(id: "tail", minX: 170, minY: 0, width: 100, height: 100)

    let translations = CanvasCollisionResolutionService.resolveOverlaps(
        bodies: [seedBody, middleBody, tailBody],
        seedBodyID: seedBody.id
    )

    let seedTranslation = translations[seedBody.id] ?? .zero
    let middleTranslation = translations[middleBody.id] ?? .zero
    let tailTranslation = translations[tailBody.id] ?? .zero
    expectAlmostEqual(seedTranslation.dx, -10)
    expectAlmostEqual(seedTranslation.dy, 0)
    expectAlmostEqual(middleTranslation.dx, 10)
    expectAlmostEqual(middleTranslation.dy, 0)
    expectAlmostEqual(tailTranslation.dx, 20)
    expectAlmostEqual(tailTranslation.dy, 0)
}

private func makeCollisionBody(
    id: String,
    minX: Double,
    minY: Double,
    width: Double,
    height: Double
) -> CanvasCollisionBody {
    CanvasCollisionBody(
        id: .node(CanvasNodeID(rawValue: id)),
        nodeIDs: [CanvasNodeID(rawValue: id)],
        shape: CanvasCollisionShape(
            rect: CanvasRect(minX: minX, minY: minY, width: width, height: height)
        )
    )
}

private func expectAlmostEqual(
    _ lhs: Double,
    _ rhs: Double,
    accuracy: Double = 0.000_001
) {
    #expect(abs(lhs - rhs) <= accuracy)
}
