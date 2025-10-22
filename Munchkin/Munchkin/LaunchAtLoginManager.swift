import Foundation
import AppKit
import ServiceManagement

enum LaunchAtLoginError: LocalizedError {
    case unsupported
    case registrationFailed(Error)
    case helperNotFound

    var errorDescription: String? {
        switch self {
        case .unsupported: return "Requires macOS 13 or later."
        case .registrationFailed(let e): return "Failed to update login item: \(e.localizedDescription)"
        case .helperNotFound: return "Login Item helper target not found in app bundle."
        }
    }
}

final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    // Update this to match the Login Item helper target's bundle identifier in Xcode
    static let helperBundleIdentifier = "dev.munchkin.loginhelper"

    @Published private(set) var isEnabled: Bool = false

    init() {
        refresh()
    }

    func refresh() {
        guard #available(macOS 13, *) else { isEnabled = false; return }
        let service = SMAppService.loginItem(identifier: Self.helperBundleIdentifier)
        isEnabled = (service.status == .enabled)
    }

    func setEnabled(_ enable: Bool) throws {
        guard #available(macOS 13, *) else { throw LaunchAtLoginError.unsupported }
        let service = SMAppService.loginItem(identifier: Self.helperBundleIdentifier)

        // Check helper exists inside the bundle at Contents/Library/LoginItems/
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Library")
            .appendingPathComponent("LoginItems")
            .appendingPathComponent("\(helperBundleName()).app")
        let exists = FileManager.default.fileExists(atPath: helperURL.path)
        if !exists { throw LaunchAtLoginError.helperNotFound }

        do {
            if enable {
                try service.register()
            } else {
                try service.unregister()
            }
            refresh()
        } catch {
            throw LaunchAtLoginError.registrationFailed(error)
        }
    }

    private func helperBundleName() -> String {
        // Derive a name from bundle identifier last path component if possible
        if let name = Self.helperBundleIdentifier.split(separator: ".").last { return String(name) }
        return "LoginItemHelper"
    }
}

