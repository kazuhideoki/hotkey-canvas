// Background: Zoom interactions need lightweight, transient feedback.
// It must not interrupt keyboard-first canvas operations.
// Responsibility: Render a non-interactive zoom-ratio popup intended for centered overlay presentation.
import Application
import SwiftUI

/// Thin gray popup that displays the current zoom ratio.
struct ZoomRatioPopup: View {
    let styleSheet: CanvasStyleSheet
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(CanvasStylePalette.color(.label))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        CanvasStylePalette.color(styleSheet.overlay.zoomPopupFillColor)
                            .opacity(styleSheet.overlay.zoomPopupFillOpacity)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        CanvasStylePalette.color(styleSheet.overlay.zoomPopupBorderColor)
                            .opacity(styleSheet.overlay.zoomPopupBorderOpacity),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: CanvasStylePalette.color(styleSheet.overlay.zoomPopupShadowColor)
                    .opacity(styleSheet.overlay.zoomPopupShadowOpacity),
                radius: 4,
                x: 0,
                y: 1
            )
    }
}
