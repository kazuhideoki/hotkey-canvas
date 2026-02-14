import AppKit
import SwiftUI

public struct CanvasHotkeyCaptureView: NSViewRepresentable {
    private let onKeyDown: (NSEvent) -> Void

    public init(onKeyDown: @escaping (NSEvent) -> Void) {
        self.onKeyDown = onKeyDown
    }

    public func makeNSView(context: Context) -> CanvasKeyCaptureNSView {
        CanvasKeyCaptureNSView(onKeyDown: onKeyDown)
    }

    public func updateNSView(_ nsView: CanvasKeyCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.focusIfPossible()
    }
}

public final class CanvasKeyCaptureNSView: NSView {
    var onKeyDown: (NSEvent) -> Void

    init(onKeyDown: @escaping (NSEvent) -> Void) {
        self.onKeyDown = onKeyDown
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var acceptsFirstResponder: Bool {
        true
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusIfPossible()
    }

    public override func keyDown(with event: NSEvent) {
        onKeyDown(event)
        super.keyDown(with: event)
    }

    func focusIfPossible() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else {
                return
            }
            window.makeFirstResponder(self)
        }
    }
}
