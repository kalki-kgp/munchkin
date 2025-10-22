import SwiftUI
import AppKit

@main
struct MunchkinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene for menu bar only app
        Settings {
            EmptyView()
        }
        .commands {
            // Remove default menu bar commands for a cleaner experience
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .help) { }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController!
    private var coordinator: Coordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)
        
        let settings = SettingsStore.shared
        let clipboard = ClipboardMonitor()
        coordinator = Coordinator(settings: settings, clipboard: clipboard)
        statusController = StatusItemController(coordinator: coordinator, settings: settings)
        statusController.setup()
        coordinator.start()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when closing windows (since we're menu bar only)
        return false
    }
}
