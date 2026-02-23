// Background: UI components need one central place for default style values and color resolution.
// Responsibility: Build default style sheet and resolve semantic color tokens to platform colors.
import AppKit
import Application
import SwiftUI

/// Default style sheet provider and semantic color resolver for canvas UI.
public enum CanvasStylePalette {
    /// Default style sheet used by canvas adapters.
    public static let defaultStyleSheet = CanvasStyleSheet(
        nodeText: CanvasNodeTextStyle(
            fontSize: 20,
            outerPadding: 12,
            editorContainerPadding: 6,
            textContainerInset: 6,
            imageTextSpacing: 10,
            imageCornerRadius: 6,
            cornerRadius: 10,
            borderLineWidth: 2.25,
            focusedBorderLineWidth: 3,
            collapsedBadgeFontSize: 15,
            collapsedBadgeTrailingOffset: 11,
            markdownLineSpacing: 4,
            markdownBlockSpacing: 8,
            markdownListMarkerSpacing: 6,
            markdownCodeFontSize: 17,
            markdownCodeBlockPadding: 8,
            markdownCodeBlockCornerRadius: 8,
            markdownCodeBlockOpacity: 0.18,
            markdownCodeBorderLineWidth: 1,
            markdownCodeBorderOpacity: 0.45,
            markdownCodeLeadingBarWidth: 4,
            markdownCodeLeadingBarOpacity: 0.8,
            markdownCodeTextOpacity: 0.95
        ),
        nodeChrome: CanvasNodeChromeStyle(
            defaultFillColor: .windowBackground,
            treeRootFillColor: .treeRootFill,
            defaultBorderColor: .separator,
            focusedBorderColor: .accent,
            connectSelectionEditingBorderColor: .connectSelectionEditing,
            connectSelectionSourceBorderColor: .connectSelectionSource,
            connectSelectionTargetBorderColor: .connectSelectionTarget
        ),
        edge: CanvasEdgeStyle(
            strokeColor: .separator,
            lineWidth: 2.25
        ),
        overlay: CanvasOverlayStyle(
            dimmedBackgroundOpacity: 0.12,
            popupBorderColor: .separator,
            popupSelectedRowColor: .accent,
            popupSelectedRowOpacity: 0.2,
            popupUnselectedRowColor: .textBackground,
            popupUnselectedRowOpacity: 0.35,
            zoomPopupFillColor: .treeRootFill,
            zoomPopupFillOpacity: 0.25,
            zoomPopupBorderColor: .separator,
            zoomPopupBorderOpacity: 0.55,
            zoomPopupShadowColor: .shadow,
            zoomPopupShadowOpacity: 0.1
        )
    )

    static func color(_ token: CanvasStyleColorToken) -> Color {
        switch token {
        case .accent:
            return .accentColor
        case .textBackground:
            return Color(nsColor: .textBackgroundColor)
        case .separator:
            return Color(nsColor: .separatorColor)
        case .windowBackground:
            return Color(nsColor: .windowBackgroundColor)
        case .treeRootFill:
            return Color(nsColor: .systemGray)
        case .label:
            return Color(nsColor: .labelColor)
        case .secondaryLabel:
            return Color(nsColor: .secondaryLabelColor)
        case .connectSelectionEditing:
            return Color(nsColor: .systemPink)
        case .connectSelectionSource:
            return Color(nsColor: .systemOrange)
        case .connectSelectionTarget:
            return Color(nsColor: .systemGreen)
        case .shadow:
            return .black
        }
    }

}
