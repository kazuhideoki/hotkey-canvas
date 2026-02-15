import AppKit
import SwiftUI

public struct CanvasHotkeyCaptureView: NSViewRepresentable {
    private let onKeyDown: (NSEvent) -> Bool
    private let isEnabled: Bool

    public init(
        isEnabled: Bool = true,
        onKeyDown: @escaping (NSEvent) -> Bool
    ) {
        self.isEnabled = isEnabled
        self.onKeyDown = onKeyDown
    }

    public func makeNSView(context: Context) -> CanvasKeyCaptureNSView {
        CanvasKeyCaptureNSView(isEnabled: isEnabled, onKeyDown: onKeyDown)
    }

    public func updateNSView(_ nsView: CanvasKeyCaptureNSView, context: Context) {
        nsView.isCaptureEnabled = isEnabled
        nsView.onKeyDown = onKeyDown
        if isEnabled {
            nsView.focusIfPossible()
        }
    }
}

public final class CanvasKeyCaptureNSView: NSView {
    var isCaptureEnabled: Bool
    var onKeyDown: (NSEvent) -> Bool

    init(isEnabled: Bool, onKeyDown: @escaping (NSEvent) -> Bool) {
        isCaptureEnabled = isEnabled
        self.onKeyDown = onKeyDown
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var acceptsFirstResponder: Bool {
        isCaptureEnabled
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusIfPossible()
    }

    public override func keyDown(with event: NSEvent) {
        // Consume handled shortcuts here to prevent AppKit's default beep/propagation.
        guard !handleKeyDown(event) else {
            return
        }
        super.keyDown(with: event)
    }

    func focusIfPossible() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else {
                return
            }
            guard self.isCaptureEnabled else {
                return
            }
            window.makeFirstResponder(self)
        }
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isCaptureEnabled else {
            return false
        }
        return onKeyDown(event)
    }
}
