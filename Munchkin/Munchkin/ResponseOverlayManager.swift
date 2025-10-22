import AppKit
import SwiftUI

enum OverlayPlacement: String, CaseIterable {
    case cursor
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

final class ResponseOverlayManager {
    static let shared = ResponseOverlayManager()

    private var window: NSWindow?
    private var host: NSHostingView<LineOverlayView>?
    private var scrollCatcherView: NSView?
    private var hideTimer: Timer?
    private var firstResponderTries = 0

    // Show lines at placement. Calls onClose when hidden by user or inactivity.
    func show(lines: [String], settings: SettingsStore, onClose: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.hideTimer?.invalidate()
            let content = LineOverlayView(lines: lines,
                                          fontSize: CGFloat(settings.overlayFontSize),
                                          textColor: Self.color(from: settings.overlayTextColor),
                                          scrollThreshold: CGFloat(settings.overlayScrollSensitivity),
                                          onClose: { [weak self] in self?.hide(); onClose() },
                                          onAttach: { [weak self] v in
                                              // Save for later; we'll set it as first responder after window is ready
                                              self?.scrollCatcherView = v
                                          })
            let hosting = NSHostingView(rootView: content)
            hosting.translatesAutoresizingMaskIntoConstraints = false

            let width = CGFloat(settings.overlayWidth)
            let lineHeight = ceil(NSFont.systemFont(ofSize: CGFloat(settings.overlayFontSize)).capHeight * 2.0)
            let size = NSSize(width: width, height: max(24, lineHeight + 8))

            // Ensure we always use OverlayWindow subclass so it can become key
            let baseWin: OverlayWindow
            if let existing = self.window as? OverlayWindow {
                baseWin = existing
            } else {
                baseWin = OverlayWindow(contentRect: NSRect(origin: .zero, size: size),
                                                 styleMask: [.borderless, .fullSizeContentView],
                                                 backing: .buffered,
                                                 defer: false)
                self.window = baseWin
            }

            let w = baseWin
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.ignoresMouseEvents = false
            w.isMovableByWindowBackground = true
            w.level = .floating
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            if settings.overlayExcludeFromScreenShare { w.sharingType = .none }

            let cv = NSView()
            cv.wantsLayer = true
            cv.layer?.backgroundColor = NSColor.clear.cgColor
            w.contentView = cv
            w.contentView?.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: w.contentView!.bottomAnchor)
            ])

            // Set size
            w.setContentSize(size)

            // Position
            let frame = self.frameForPlacement(settings: settings, windowSize: size)
            w.setFrame(frame, display: true)

            self.host = hosting
            if let ow = w as? OverlayWindow {
                ow.onClose = { [weak self] in self?.hide(); onClose() }
            }
            w.makeKeyAndOrderFront(nil)
            // Set a safe first responder to receive key events (ESC)
            w.makeFirstResponder(w.contentView)
            NSApp.activate(ignoringOtherApps: true)

            // Auto-hide after inactivity
            self.scheduleAutoHide(seconds: settings.overlayAutoHideSeconds, onClose: onClose)

            // Defer first responder setting until the view is attached to the window
            self.firstResponderTries = 0
            self.tryMakeCatcherFirstResponder()
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.hideTimer?.invalidate()
            self.window?.orderOut(nil)
        }
    }

    private func scheduleAutoHide(seconds: TimeInterval, onClose: @escaping () -> Void) {
        guard seconds > 0 else { return }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false, block: { [weak self] _ in
            self?.hide()
            onClose()
        })
        if let t = hideTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func frameForPlacement(settings: SettingsStore, windowSize: NSSize) -> NSRect {
        let m = NSEvent.mouseLocation
        let screen = screenContaining(point: m) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 100, y: 100, width: 800, height: 600)
        switch settings.overlayPlacement {
        case .cursor:
            // macOS origin bottom-left; place above cursor slightly
            let origin = CGPoint(x: max(visible.minX, min(m.x, visible.maxX - windowSize.width)),
                                 y: max(visible.minY, min(m.y - windowSize.height - 8, visible.maxY - windowSize.height)))
            return NSRect(origin: origin, size: windowSize)
        case .topLeft:
            return NSRect(x: visible.minX + 12, y: visible.maxY - windowSize.height - 12, width: windowSize.width, height: windowSize.height)
        case .topRight:
            return NSRect(x: visible.maxX - windowSize.width - 12, y: visible.maxY - windowSize.height - 12, width: windowSize.width, height: windowSize.height)
        case .bottomLeft:
            return NSRect(x: visible.minX + 12, y: visible.minY + 12, width: windowSize.width, height: windowSize.height)
        case .bottomRight:
            return NSRect(x: visible.maxX - windowSize.width - 12, y: visible.minY + 12, width: windowSize.width, height: windowSize.height)
        }
    }

    private func screenContaining(point: NSPoint) -> NSScreen? {
        for s in NSScreen.screens {
            if s.frame.contains(point) { return s }
        }
        return nil
    }

    private func tryMakeCatcherFirstResponder() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self = self else { return }
            self.firstResponderTries += 1
            if let sc = self.scrollCatcherView, let win = sc.window {
                win.makeFirstResponder(sc)
            } else if self.firstResponderTries < 15 {
                self.tryMakeCatcherFirstResponder()
            }
        }
    }
}

final class OverlayWindow: NSWindow {
    var onClose: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
    }
    override func keyDown(with event: NSEvent) {
        // 53 is ESC keycode
        if event.keyCode == 53 {
            onClose?()
        } else {
            super.keyDown(with: event)
        }
    }
}

extension ResponseOverlayManager {
    static func color(from name: String) -> Color {
        switch name.lowercased() {
        case "white": return Color.white
        case "label": return Color(NSColor.labelColor)
        default: return Color.black
        }
    }
}
