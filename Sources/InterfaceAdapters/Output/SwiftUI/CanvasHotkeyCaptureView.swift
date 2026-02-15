// Background: SwiftUI alone cannot reliably keep a key-capture responder during rapid editing state changes.
// Responsibility: Host an AppKit responder that captures canvas hotkeys and coordinates first-responder handoff.
import AppKit
import SwiftUI

/// SwiftUI bridge that installs an AppKit key-capture view.
public struct CanvasHotkeyCaptureView: NSViewRepresentable {
    private let onKeyDown: (NSEvent) -> Bool
    private let isEnabled: Bool

    /// Creates a key-capture bridge.
    /// - Parameters:
    ///   - isEnabled: Whether key capture should be active.
    ///   - onKeyDown: Handler invoked for key-down events.
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
        } else {
            nsView.resignIfNeeded()
        }
    }
}

/// AppKit responder used to capture canvas shortcuts while not editing text.
public final class CanvasKeyCaptureNSView: NSView {
    var isCaptureEnabled: Bool
    var onKeyDown: (NSEvent) -> Bool
    /// Monotonic token used to discard stale asynchronous focus requests.
    private var focusRequestID: UInt64 = 0

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
        guard isCaptureEnabled else {
            return
        }
        focusIfPossible()
    }

    public override func keyDown(with event: NSEvent) {
        // Consume handled shortcuts here to prevent AppKit's default beep/propagation.
        guard !handleKeyDown(event) else {
            return
        }
        super.keyDown(with: event)
    }

    /// Attempts to focus this view as first responder if capture is still enabled.
    func focusIfPossible() {
        focusRequestID &+= 1
        let requestID = focusRequestID
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else {
                return
            }
            guard self.isCaptureEnabled else {
                return
            }
            guard self.focusRequestID == requestID else {
                return
            }
            guard window.firstResponder !== self else {
                return
            }
            window.makeFirstResponder(self)
        }
    }

    /// Resigns first responder immediately when this capture view is currently focused.
    func resignIfNeeded() {
        focusRequestID &+= 1
        guard let window = self.window else {
            return
        }
        guard window.firstResponder === self else {
            return
        }
        window.makeFirstResponder(nil)
    }

    /// Handles key-down only while capture is enabled.
    /// - Parameter event: Incoming key-down event.
    /// - Returns: `true` when the event is handled and should be consumed.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isCaptureEnabled else {
            return false
        }
        return onKeyDown(event)
    }
}
