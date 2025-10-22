import AppKit
import SwiftUI

final class OverlaySettingsWindowController: NSWindowController, NSWindowDelegate {
    private var retainedSelf: OverlaySettingsWindowController?

    convenience init(settings: SettingsStore) {
        let view = OverlaySettingsView(settings: settings)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Overlay Settings"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: 520, height: 420))
        window.center()
        self.init(window: window)
        window.delegate = self
        // retain self while window is open
        self.retainedSelf = self
    }

    func windowWillClose(_ notification: Notification) {
        retainedSelf = nil
    }
}
