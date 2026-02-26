// Background: Shortcut catalog builds IDs and labels from movement directions.
// Responsibility: Provide direction-specific label helpers for shortcut definition factories.
extension CanvasShortcutCatalogService {
    static func focusDirectionIDSuffix(_ direction: CanvasFocusDirection) -> String {
        switch direction {
        case .up:
            "Up"
        case .down:
            "Down"
        case .left:
            "Left"
        case .right:
            "Right"
        }
    }

    static func focusDirectionLabel(_ direction: CanvasFocusDirection) -> String {
        switch direction {
        case .up:
            "Up"
        case .down:
            "Down"
        case .left:
            "Left"
        case .right:
            "Right"
        }
    }

    static func nodeDirectionIDSuffix(_ direction: CanvasNodeMoveDirection) -> String {
        switch direction {
        case .up:
            "Up"
        case .down:
            "Down"
        case .left:
            "Left"
        case .right:
            "Right"
        case .upLeft:
            "UpLeft"
        case .upRight:
            "UpRight"
        case .downLeft:
            "DownLeft"
        case .downRight:
            "DownRight"
        }
    }

    static func nodeDirectionLabel(_ direction: CanvasNodeMoveDirection) -> String {
        switch direction {
        case .up:
            "Up"
        case .down:
            "Down"
        case .left:
            "Left"
        case .right:
            "Right"
        case .upLeft:
            "Up Left"
        case .upRight:
            "Up Right"
        case .downLeft:
            "Down Left"
        case .downRight:
            "Down Right"
        }
    }
}
