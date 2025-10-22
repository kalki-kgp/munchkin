# How to Add a Login Item Helper in Xcode (for "Launch at Login")

Follow these steps to add and wire up a Login Item Helper in Xcode so your “Launch at Login” toggle works as expected.

---

## 1. Create the Login Helper Target

- In Xcode: **File → New → Target…**
- Platform: **macOS** → Template: **App** → Next
- **Product Name:** `MunchkinLoginHelper`
- **Team:** your team (or “Sign to Run Locally” if you don’t have a paid account)
- **Bundle Identifier:** `dev.munchkin.loginhelper`
- **Interface:** SwiftUI; **Language:** Swift
- Click **Finish**

---

## 2. Make the Helper a Background App

- Select target: `MunchkinLoginHelper` → **Info** tab
- Add key: `Application is agent (UIElement)` = `YES`
  - This hides the Dock icon and menu bar for the helper.

---

## 3. Ensure Code Signing Works

- Select target: `MunchkinLoginHelper` → **Signing & Capabilities**
- Check “Automatically manage signing”
- Set **Team**: same as your main app
- **Certificate:** “Apple Development” (for local dev)
- Repeat for your main app target if needed

---

## 4. Prevent the Helper From Being Installed Standalone

- Select target: `MunchkinLoginHelper` → **Build Settings**
- Search “Skip Install” → set to `YES` (for all configurations)
  - This ensures Xcode won’t ship the helper as a standalone app.

---

## 5. Embed the Helper Inside the Main App Bundle

- Select main app target (`Munchkin`) → **Build Phases**
- Click “+” at the top → **New Copy Files Phase**
- Expand the Copy Files phase:
  - **Destination:** `Wrapper`
  - **Subpath:** `Contents/Library/LoginItems`
  - Click “+” → add `MunchkinLoginHelper.app` (helper target’s product)
- (Optional) Drag this phase above “Embed Frameworks” for better organization

**After building, you should see:**
```
Munchkin.app/Contents/Library/LoginItems/MunchkinLoginHelper.app
```

---

## 6. Minimal Helper Code

Replace the helper’s default app code with a tiny launcher.  
Create `AppDelegate.swift` in the helper and wire it up.

**App entry (MunchkinLoginHelperApp.swift):**
```swift
import SwiftUI

@main
struct MunchkinLoginHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}
```

**Minimal App Delegate (AppDelegate.swift):**
```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        launchMainAndQuit()
    }

    private func launchMainAndQuit() {
        // Helper location: Main.app/Contents/Library/LoginItems/Helper.app
        // Go up 4 levels to Main.app
        let helperURL = Bundle.main.bundleURL
        let mainAppURL = helperURL
            .deletingLastPathComponent() // LoginItems
            .deletingLastPathComponent() // Library
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // Main.app

        NSWorkspace.shared.openApplication(at: mainAppURL,
                                           configuration: NSWorkspace.OpenConfiguration(),
                                           completionHandler: nil)
        NSApp.terminate(nil)
    }
}
```
**This launches the main app and immediately quits the helper.**

---

## 7. Match Bundle Identifier in Code

- In main app source, ensure you have:
  ```swift
  LaunchAtLoginManager.helperBundleIdentifier = "dev.munchkin.loginhelper"
  ```
- The string must exactly match the helper’s bundle identifier (in Target → General → Bundle Identifier).

---

## 8. Build and Test

- **Build:** Product → Build (Release or Debug)
- **Run:** Launch the main app (Cmd+R)
- **Toggle:** Menubar → Settings… → General → “Launch at Login”

### On macOS 13+:
- The first time may prompt for approval or silently register.
- Check: System Settings → General → Login Items should show `MunchkinLoginHelper`.

- Quit the app, log out and back in (or reboot) to verify launch at login.

**Common issues & checks:**
- Verify bundle ID matches `dev.munchkin.loginhelper`
- If toggle fails:
  - Both main and helper targets must be signed (“Apple Development” is enough for local)
  - On old macOS (<13), `SMAppService.loginItem` is not supported.
- If helper shows Dock icon:
  - Ensure `Application is agent (UIElement)` = YES in helper Info.
- If app doesn’t open at login:
  - Confirm the helper’s code matches sample above.
  - Confirm path to main app is correct (the “up 4 levels” logic).

**App Sandbox**
- You can keep App Sandbox off during development.
- If sandbox is enabled, it won’t block `SMAppService`, but ensure “Outgoing Connections (Client)” is ON for networking after login.

---

### Optional

- If you’d like, I can generate the minimal helper files (App + AppDelegate) and add them to your repo for drag‑and‑drop use.
- I can also add a preflight check in the main app to show a friendlier message if the helper isn’t embedded.

---

## DMG Packaging After Adding the Login Helper

**Q: Can I still bundle the .dmg as before?**

> **Yes!**  
> Those exact DMG steps work after adding the login helper. The helper is embedded in the .app bundle, so copying the app into the DMG brings the helper automatically.

### What to Check Before Packaging

- Build Release so the helper gets embedded:
  - Main app target → Build Phases → Copy Files (Destination: Wrapper, Subpath: Contents/Library/LoginItems) contains `MunchkinLoginHelper.app`
  - Helper target → Build Settings → Skip Install = YES
  - (Optional) Main app → Build Phases → Target Dependencies includes `MunchkinLoginHelper` (so it builds before copying)
- Double-check the bundle:
  - ```
    ls ".../Release/Munchkin.app/Contents/Library/LoginItems"
    ```

### Package as DMG (same commands)

```sh
mkdir -p dist/Munchkin_DMG
cp -R "Munchkin.app" dist/Munchkin_DMG/
ln -s /Applications dist/Munchkin_DMG/Applications
hdiutil create -volname "Munchkin" -srcfolder "dist/Munchkin_DMG" -ov -format UDZO "Munchkin.dmg"
```

---

#### Notes

- No Apple Developer account is required for this. (For distribution, users will need to right-click → Open for the first launch, since it isn’t notarized.)
- “Launch at Login” works from the embedded helper even when shipped via DMG; users may be prompted to approve the helper in System Settings → General → Login Items.
- If App Sandbox is enabled, keep “Outgoing Connections (Client)” enabled so the app can connect to the network after login.

---

#### Optional

- Want me to add a small script (e.g., `scripts/package.sh`) to build Release, verify the helper is embedded, and create the DMG automatically? Let me know!
