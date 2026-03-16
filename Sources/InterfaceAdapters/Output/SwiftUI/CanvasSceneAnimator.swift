// Background: Canvas animation should be driven by one shared world-space snapshot.
// Responsibility: Publish an interpolated canvas scene during animated transitions.
import Combine
import Foundation

@MainActor
final class CanvasSceneAnimator: ObservableObject {
    static let durationSeconds: Double = 0.18
    static let frameIntervalNanoseconds: UInt64 = 16_666_667

    @Published private(set) var renderedScene: CanvasSceneSnapshot?

    private var animationTask: Task<Void, Never>?

    func setScene(_ scene: CanvasSceneSnapshot, animated: Bool) {
        guard animated, let source = renderedScene else {
            cancelAnimation()
            renderedScene = scene
            return
        }
        guard source != scene else {
            renderedScene = scene
            return
        }
        guard source.hasAnimatedDifference(comparedTo: scene) else {
            cancelAnimation()
            renderedScene = scene
            return
        }

        cancelAnimation()
        animationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            let startTime = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let rawProgress = min(max(elapsed / Self.durationSeconds, 0), 1)
                let easedProgress = rawProgress * rawProgress * (3 - (2 * rawProgress))
                renderedScene = source.interpolated(to: scene, progress: easedProgress)
                guard rawProgress < 1 else {
                    animationTask = nil
                    return
                }
                try? await Task.sleep(nanoseconds: Self.frameIntervalNanoseconds)
            }
        }
    }

    func cancelAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}
