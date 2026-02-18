// Background: Keyboard-driven canvas editing needs deterministic zoom stepping for fast navigation.
// Responsibility: Provide bounded zoom level transitions for CanvasView.
import Foundation

extension CanvasView {
    static let zoomScales: [Double] = [4.0, 3.0, 2.0, 1.5, 1.25, 1.0, 0.75, 0.5, 0.25]

    func applyZoom(action: CanvasZoomAction) {
        zoomScale = nextZoomScale(for: action, currentScale: zoomScale)
    }

    private func nextZoomScale(for action: CanvasZoomAction, currentScale: Double) -> Double {
        let currentIndex = nearestZoomScaleIndex(to: currentScale)

        switch action {
        case .zoomIn:
            guard currentIndex > 0 else {
                return Self.zoomScales[0]
            }
            return Self.zoomScales[currentIndex - 1]
        case .zoomOut:
            guard currentIndex < (Self.zoomScales.count - 1) else {
                return Self.zoomScales[Self.zoomScales.count - 1]
            }
            return Self.zoomScales[currentIndex + 1]
        }
    }

    private func nearestZoomScaleIndex(to scale: Double) -> Int {
        var bestIndex = 0
        var bestDistance = abs(Self.zoomScales[0] - scale)

        for index in 1..<Self.zoomScales.count {
            let distance = abs(Self.zoomScales[index] - scale)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }
}
