// Background: Zoom interactions need lightweight, transient feedback.
// It must not interrupt keyboard-first canvas operations.
// Responsibility: Render a non-interactive zoom-ratio popup intended for centered overlay presentation.
import SwiftUI

/// Thin gray popup that displays the current zoom ratio.
struct ZoomRatioPopup: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(nsColor: .labelColor))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .systemGray).opacity(0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 1)
    }
}
