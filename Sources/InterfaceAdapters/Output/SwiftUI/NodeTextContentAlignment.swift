// Background: Diagram nodes need a different text layout policy from tree nodes.
// Responsibility: Define shared text alignment semantics across SwiftUI and AppKit renderers.
import AppKit
import SwiftUI

/// Shared node text alignment policy used by committed rendering and inline editing.
enum NodeTextContentAlignment: Equatable {
    case topLeading
    case center

    /// SwiftUI frame alignment used to position text containers inside nodes.
    var frameAlignment: Alignment {
        switch self {
        case .topLeading:
            .topLeading
        case .center:
            .center
        }
    }

    /// SwiftUI multiline text alignment used for plain text rendering.
    var textAlignment: TextAlignment {
        switch self {
        case .topLeading:
            .leading
        case .center:
            .center
        }
    }

    /// Horizontal stack alignment used by markdown and image+text layouts.
    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .topLeading:
            .leading
        case .center:
            .center
        }
    }

    /// Paragraph alignment used by `NSTextView` editing.
    var paragraphAlignment: NSTextAlignment {
        switch self {
        case .topLeading:
            .natural
        case .center:
            .center
        }
    }
}
