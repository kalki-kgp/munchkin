import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let content = ModernSettingsView()
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Munchkin Settings"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: 720, height: 520))
        window.center()
        self.init(window: window)
    }
}

