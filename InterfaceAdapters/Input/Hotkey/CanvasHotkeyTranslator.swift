import AppKit
import Domain

public struct CanvasHotkeyTranslator {
    public init() {}

    public func translate(_ event: NSEvent) -> [CanvasCommand] {
        guard isShiftEnter(event) else {
            return []
        }
        return [.addNode]
    }
}

extension CanvasHotkeyTranslator {
    private func isShiftEnter(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.keyCode == 36 else {
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .function]
        return flags.contains(.shift) && flags.isDisjoint(with: disallowed)
    }
}
