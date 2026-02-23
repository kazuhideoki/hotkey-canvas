// Background: UI styling will evolve over time and needs a module-safe shape contract.
// Responsibility: Define UI-independent style values shared by adapters.
/// Immutable style sheet consumed by UI adapters.
public struct CanvasStyleSheet: Equatable, Sendable {
    /// Text and spacing defaults used by node content.
    public let nodeText: CanvasNodeTextStyle
    /// Node chrome defaults for fill, border, and emphasis states.
    public let nodeChrome: CanvasNodeChromeStyle
    /// Edge rendering defaults.
    public let edge: CanvasEdgeStyle
    /// Overlay/popup defaults.
    public let overlay: CanvasOverlayStyle

    /// Creates a style sheet.
    /// - Parameters:
    ///   - nodeText: Text and spacing defaults used by node content.
    ///   - nodeChrome: Node chrome defaults for fill, border, and emphasis states.
    ///   - edge: Edge rendering defaults.
    ///   - overlay: Overlay/popup defaults.
    public init(
        nodeText: CanvasNodeTextStyle,
        nodeChrome: CanvasNodeChromeStyle,
        edge: CanvasEdgeStyle,
        overlay: CanvasOverlayStyle
    ) {
        self.nodeText = nodeText
        self.nodeChrome = nodeChrome
        self.edge = edge
        self.overlay = overlay
    }
}

/// Semantic color token used by UI adapters to resolve platform colors.
public enum CanvasStyleColorToken: String, Equatable, Sendable {
    case accent
    case textBackground
    case separator
    case windowBackground
    case treeRootFill
    case label
    case secondaryLabel
    case connectSelectionEditing
    case connectSelectionSource
    case connectSelectionTarget
    case shadow
}

/// Node text style values.
public struct CanvasNodeTextStyle: Equatable, Sendable {
    public let fontSize: Double
    public let outerPadding: Double
    public let editorContainerPadding: Double
    public let textContainerInset: Double
    public let imageTextSpacing: Double
    public let imageCornerRadius: Double
    public let cornerRadius: Double
    public let borderLineWidth: Double
    public let focusedBorderLineWidth: Double
    public let collapsedBadgeFontSize: Double
    public let collapsedBadgeTrailingOffset: Double
    public let markdownLineSpacing: Double
    public let markdownBlockSpacing: Double
    public let markdownListMarkerSpacing: Double
    public let markdownCodeFontSize: Double
    public let markdownCodeBlockPadding: Double
    public let markdownCodeBlockCornerRadius: Double
    public let markdownCodeBlockOpacity: Double
    public let markdownCodeBorderLineWidth: Double
    public let markdownCodeBorderOpacity: Double
    public let markdownCodeLeadingBarWidth: Double
    public let markdownCodeLeadingBarOpacity: Double
    public let markdownCodeTextOpacity: Double

    /// Creates node text style values.
    public init(
        fontSize: Double,
        outerPadding: Double,
        editorContainerPadding: Double,
        textContainerInset: Double,
        imageTextSpacing: Double,
        imageCornerRadius: Double,
        cornerRadius: Double,
        borderLineWidth: Double,
        focusedBorderLineWidth: Double,
        collapsedBadgeFontSize: Double,
        collapsedBadgeTrailingOffset: Double,
        markdownLineSpacing: Double,
        markdownBlockSpacing: Double,
        markdownListMarkerSpacing: Double,
        markdownCodeFontSize: Double,
        markdownCodeBlockPadding: Double,
        markdownCodeBlockCornerRadius: Double,
        markdownCodeBlockOpacity: Double,
        markdownCodeBorderLineWidth: Double,
        markdownCodeBorderOpacity: Double,
        markdownCodeLeadingBarWidth: Double,
        markdownCodeLeadingBarOpacity: Double,
        markdownCodeTextOpacity: Double
    ) {
        self.fontSize = fontSize
        self.outerPadding = outerPadding
        self.editorContainerPadding = editorContainerPadding
        self.textContainerInset = textContainerInset
        self.imageTextSpacing = imageTextSpacing
        self.imageCornerRadius = imageCornerRadius
        self.cornerRadius = cornerRadius
        self.borderLineWidth = borderLineWidth
        self.focusedBorderLineWidth = focusedBorderLineWidth
        self.collapsedBadgeFontSize = collapsedBadgeFontSize
        self.collapsedBadgeTrailingOffset = collapsedBadgeTrailingOffset
        self.markdownLineSpacing = markdownLineSpacing
        self.markdownBlockSpacing = markdownBlockSpacing
        self.markdownListMarkerSpacing = markdownListMarkerSpacing
        self.markdownCodeFontSize = markdownCodeFontSize
        self.markdownCodeBlockPadding = markdownCodeBlockPadding
        self.markdownCodeBlockCornerRadius = markdownCodeBlockCornerRadius
        self.markdownCodeBlockOpacity = markdownCodeBlockOpacity
        self.markdownCodeBorderLineWidth = markdownCodeBorderLineWidth
        self.markdownCodeBorderOpacity = markdownCodeBorderOpacity
        self.markdownCodeLeadingBarWidth = markdownCodeLeadingBarWidth
        self.markdownCodeLeadingBarOpacity = markdownCodeLeadingBarOpacity
        self.markdownCodeTextOpacity = markdownCodeTextOpacity
    }
}

/// Node chrome style values.
public struct CanvasNodeChromeStyle: Equatable, Sendable {
    public let defaultFillColor: CanvasStyleColorToken
    public let treeRootFillColor: CanvasStyleColorToken
    public let defaultBorderColor: CanvasStyleColorToken
    public let focusedBorderColor: CanvasStyleColorToken
    public let connectSelectionEditingBorderColor: CanvasStyleColorToken
    public let connectSelectionSourceBorderColor: CanvasStyleColorToken
    public let connectSelectionTargetBorderColor: CanvasStyleColorToken

    /// Creates node chrome style values.
    public init(
        defaultFillColor: CanvasStyleColorToken,
        treeRootFillColor: CanvasStyleColorToken,
        defaultBorderColor: CanvasStyleColorToken,
        focusedBorderColor: CanvasStyleColorToken,
        connectSelectionEditingBorderColor: CanvasStyleColorToken,
        connectSelectionSourceBorderColor: CanvasStyleColorToken,
        connectSelectionTargetBorderColor: CanvasStyleColorToken
    ) {
        self.defaultFillColor = defaultFillColor
        self.treeRootFillColor = treeRootFillColor
        self.defaultBorderColor = defaultBorderColor
        self.focusedBorderColor = focusedBorderColor
        self.connectSelectionEditingBorderColor = connectSelectionEditingBorderColor
        self.connectSelectionSourceBorderColor = connectSelectionSourceBorderColor
        self.connectSelectionTargetBorderColor = connectSelectionTargetBorderColor
    }
}

/// Edge style values.
public struct CanvasEdgeStyle: Equatable, Sendable {
    public let strokeColor: CanvasStyleColorToken
    public let lineWidth: Double

    /// Creates edge style values.
    public init(strokeColor: CanvasStyleColorToken, lineWidth: Double) {
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
    }
}

/// Overlay and popup style values.
public struct CanvasOverlayStyle: Equatable, Sendable {
    public let dimmedBackgroundOpacity: Double
    public let popupBorderColor: CanvasStyleColorToken
    public let popupSelectedRowColor: CanvasStyleColorToken
    public let popupSelectedRowOpacity: Double
    public let popupUnselectedRowColor: CanvasStyleColorToken
    public let popupUnselectedRowOpacity: Double
    public let zoomPopupFillColor: CanvasStyleColorToken
    public let zoomPopupFillOpacity: Double
    public let zoomPopupBorderColor: CanvasStyleColorToken
    public let zoomPopupBorderOpacity: Double
    public let zoomPopupShadowColor: CanvasStyleColorToken
    public let zoomPopupShadowOpacity: Double

    /// Creates overlay and popup style values.
    public init(
        dimmedBackgroundOpacity: Double,
        popupBorderColor: CanvasStyleColorToken,
        popupSelectedRowColor: CanvasStyleColorToken,
        popupSelectedRowOpacity: Double,
        popupUnselectedRowColor: CanvasStyleColorToken,
        popupUnselectedRowOpacity: Double,
        zoomPopupFillColor: CanvasStyleColorToken,
        zoomPopupFillOpacity: Double,
        zoomPopupBorderColor: CanvasStyleColorToken,
        zoomPopupBorderOpacity: Double,
        zoomPopupShadowColor: CanvasStyleColorToken,
        zoomPopupShadowOpacity: Double
    ) {
        self.dimmedBackgroundOpacity = dimmedBackgroundOpacity
        self.popupBorderColor = popupBorderColor
        self.popupSelectedRowColor = popupSelectedRowColor
        self.popupSelectedRowOpacity = popupSelectedRowOpacity
        self.popupUnselectedRowColor = popupUnselectedRowColor
        self.popupUnselectedRowOpacity = popupUnselectedRowOpacity
        self.zoomPopupFillColor = zoomPopupFillColor
        self.zoomPopupFillOpacity = zoomPopupFillOpacity
        self.zoomPopupBorderColor = zoomPopupBorderColor
        self.zoomPopupBorderOpacity = zoomPopupBorderOpacity
        self.zoomPopupShadowColor = zoomPopupShadowColor
        self.zoomPopupShadowOpacity = zoomPopupShadowOpacity
    }
}
