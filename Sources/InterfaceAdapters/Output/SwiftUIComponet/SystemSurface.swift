// Background: Overlay views should express platform-native surface intent without hardcoding material literals.
// Responsibility: Apply one semantic system surface token as a unified SwiftUI background style.
import Application
import SwiftUI

/// View modifier that paints a semantic system surface resolved by `CanvasStylePalette`.
struct SystemSurface: ViewModifier {
    let token: CanvasSystemSurfaceToken

    func body(content: Content) -> some View {
        content.background(CanvasStylePalette.surface(token))
    }
}

extension View {
    /// Applies a semantic system surface token.
    /// - Parameter token: Semantic surface role for this view.
    /// - Returns: View with resolved platform-native background surface.
    func systemSurface(_ token: CanvasSystemSurfaceToken) -> some View {
        modifier(SystemSurface(token: token))
    }
}
