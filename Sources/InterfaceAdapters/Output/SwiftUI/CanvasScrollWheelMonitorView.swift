// Background: SwiftUI gesture APIs do not consistently expose mouse-wheel deltas for canvas panning on macOS.
// Responsibility: Install an AppKit local monitor and forward scroll-wheel events to SwiftUI state handlers.
import AppKit
import SwiftUI

/// SwiftUI bridge that listens to local scroll-wheel events.
public struct CanvasScrollWheelMonitorView: NSViewRepresentable {
    private let isEnabled: Bool
    private let onScrollWheel: (NSEvent) -> Bool

    /// Creates a scroll-wheel monitor bridge.
    /// - Parameters:
    ///   - isEnabled: Whether scroll-wheel monitoring is active.
    ///   - onScrollWheel: Handler invoked for scroll-wheel events.
    public init(
        isEnabled: Bool = true,
        onScrollWheel: @escaping (NSEvent) -> Bool
    ) {
        self.isEnabled = isEnabled
        self.onScrollWheel = onScrollWheel
    }

    public func makeNSView(context: Context) -> CanvasScrollWheelMonitorNSView {
        CanvasScrollWheelMonitorNSView(isEnabled: isEnabled, onScrollWheel: onScrollWheel)
    }

    public func updateNSView(_ nsView: CanvasScrollWheelMonitorNSView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onScrollWheel = onScrollWheel
    }
}

/// AppKit host view that owns the local event monitor lifecycle.
public final class CanvasScrollWheelMonitorNSView: NSView {
    var isEnabled: Bool
    var onScrollWheel: (NSEvent) -> Bool

    private var localMonitor: (any NSObjectProtocol)?

    init(isEnabled: Bool, onScrollWheel: @escaping (NSEvent) -> Bool) {
        self.isEnabled = isEnabled
        self.onScrollWheel = onScrollWheel
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        removeMonitorIfNeeded()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeMonitorIfNeeded()
        } else {
            installMonitorIfNeeded()
        }
    }

    private func installMonitorIfNeeded() {
        guard localMonitor == nil else {
            return
        }
        guard
            let monitor = NSEvent.addLocalMonitorForEvents(
                matching: .scrollWheel,
                handler: { [weak self] event in
                    guard let self else {
                        return event
                    }
                    guard self.isEnabled else {
                        return event
                    }
                    guard event.window === self.window else {
                        return event
                    }
                    if self.onScrollWheel(event) {
                        return nil
                    }
                    return event
                }) as? any NSObjectProtocol
        else {
            preconditionFailure("Failed to create local scroll-wheel monitor token.")
        }
        localMonitor = monitor
    }

    private func removeMonitorIfNeeded() {
        guard let localMonitor else {
            return
        }
        NSEvent.removeMonitor(localMonitor)
        self.localMonitor = nil
    }
}
