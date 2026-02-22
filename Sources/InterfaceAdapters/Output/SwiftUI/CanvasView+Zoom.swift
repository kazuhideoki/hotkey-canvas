// Background: Keyboard-driven canvas editing needs deterministic zoom stepping for fast navigation.
// Responsibility: Provide bounded zoom level transitions for CanvasView.
import Foundation
import SwiftUI

extension CanvasView {
    static let zoomScales: [Double] = [4.0, 3.0, 2.0, 1.5, 1.25, 1.0, 0.75, 0.5, 0.25]
    static let zoomRatioPopupDurationNanoseconds: UInt64 = 850_000_000

    func applyZoom(action: CanvasZoomAction) {
        let nextScale = Self.nextZoomScale(for: action, currentScale: zoomScale)
        zoomScale = nextScale
        presentZoomRatioPopup(for: nextScale)
    }

    static func nextZoomScale(for action: CanvasZoomAction, currentScale: Double) -> Double {
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

    static func nearestZoomScaleIndex(to scale: Double) -> Int {
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

    static func zoomRatioText(for scale: Double) -> String {
        let percentage = Int((scale * 100).rounded())
        return "\(percentage)%"
    }

    func presentZoomRatioPopup(for scale: Double) {
        zoomRatioPopupRequestID &+= 1
        let currentRequestID = zoomRatioPopupRequestID
        withAnimation(.easeOut(duration: 0.12)) {
            zoomRatioPopupText = Self.zoomRatioText(for: scale)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.zoomRatioPopupDurationNanoseconds)
            guard zoomRatioPopupRequestID == currentRequestID else {
                return
            }
            withAnimation(.easeOut(duration: 0.12)) {
                zoomRatioPopupText = nil
            }
        }
    }
}
