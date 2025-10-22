Munchkin — Background Clipboard → LLM → Clipboard (macOS)

Overview
- Menubar-only app (no Dock icon) that watches your clipboard.
- It accumulates copied text until there’s 5 seconds of no new copies, then sends the combined text to your selected provider (Nebius, OpenAI, Anthropic, or Groq).
- As soon as a response arrives, it writes the response back to the clipboard so you can paste it immediately.

Key Behaviors
- Accumulation window: 5 seconds of quiet after the last copy event triggers a send.
- Multiple quick copies are joined with a configurable delimiter (default: blank line).
- Loop guard prevents self-triggering when the app writes the clipboard.
- If you copy while a request is in-flight, those new copies will be queued for the next cycle.

What You Need
1) Xcode installed (from the Mac App Store).
2) API keys for your provider(s) (set in Keychain via the app): Nebius, OpenAI, Anthropic, or Groq.

Project Setup in Xcode (one-time)
1. Open Xcode → File → New → Project…
2. Choose “App” under the macOS tab. Click Next.
3. Product Name: Munchkin; Interface: SwiftUI; Language: Swift. Click Next.
4. Save the project (anywhere). Quit Xcode temporarily.
5. In Finder, drag the contents of this repository’s `Munchkin` folder into your Xcode project’s root group:
   - Add: `MunchkinApp.swift`, `StatusItemController.swift`, `ClipboardMonitor.swift`, `Coordinator.swift`, `LLMClient.swift`, `NebiusClient.swift`, `OpenAIClient.swift`, `AnthropicClient.swift`, `GroqClient.swift`, `KeychainStore.swift`, `Settings.swift`, `Info.plist`.
   - When prompted, ensure “Copy items if needed” is checked, and your app target is selected.
6. Set LSUIElement so it runs as a menubar app:
   - In Xcode, select your app target → Info tab.
   - Add a new key to the Info section: `Application is agent (UIElement)` with value `YES`.
   - Alternatively, merge the provided `Info.plist` content into your target’s Info.plist and ensure LSUIElement is true.
7. Capabilities (optional, if you enable App Sandbox):
   - If App Sandbox is enabled, also enable Outgoing Network Connections.
8. Build & Run (Cmd+R). The app shows as an icon in the macOS menu bar (no Dock icon).

First Run
- Menubar → Provider → choose Nebius/OpenAI/Anthropic/Groq.
- Menubar → “Set <Provider> API Key…”, paste your key.
- Optional: “Refresh Models” then choose a model under “Model”.
- Ensure “Active” is checked in the menu.
- Copy text; after 5 seconds of no new copies, the app sends the combined text and replaces your clipboard with the response.

Menu Items
- State: current state.
- Provider: Nebius, OpenAI, Anthropic, Groq.
- Active: toggle processing.
- Stealth Mode: compact indicator (I/A/⏳/⏸; shows ‘R’ for 5 seconds after a response is copied).
- Send Now: send immediately.
- Model: list of models (dynamic per provider).
- Refresh Models: fetch provider models.
- System Prompt: preview, toggle “Use System Prompt”, and edit.
- Set <Provider> API Key…: per-provider key in Keychain.
- Quit.

Privacy Notes
- Sends plaintext clipboard data only when Active.
- Keys stored per provider in Keychain.
- Minimal console logs by default.

Troubleshooting
- If the menubar icon doesn’t show, confirm LSUIElement=YES and successful build.
- If requests fail, verify provider API key and network. With App Sandbox, enable “Outgoing Connections (Client)”.
- Loop guard is enabled; avoid clipboard tools that rewrite content.

App Icon (Finder/About) and Status Bar Icon
1) App Icon (bundle icon shown in Finder/About):
   - In Xcode, ensure you have an Asset Catalog.
   - Add an “App Icon” set named `AppIcon`.
   - Provide 1024×1024 source (Xcode can scale) or fill required sizes.
   - Target → General → App Icons: choose `AppIcon`.
2) Status Bar Icon (menubar):
   - Add a monochrome template PDF/PNG to Assets named `StatusIcon` (≈18×18 pt design).
   - In Asset inspector, set “Render As: Template Image”.
   - The code auto-loads it (see `StatusItemController.applyStatusIcon()`); the menubar will show the icon plus title/time (or letters in Stealth Mode).

Packaging without Developer Account (No Notarization)
Option A: ZIP
- Build Release (Scheme → Edit Scheme → Build Configuration: Release).
- Find `Munchkin.app` in DerivedData `Build/Products/Release/`.
- `ditto -c -k --keepParent "Munchkin.app" "Munchkin.zip"` and share.
Option B: DMG
- Stage: `mkdir -p dist/Munchkin_DMG && cp -R "Munchkin.app" dist/Munchkin_DMG/ && ln -s /Applications dist/Munchkin_DMG/Applications`
- Create: `hdiutil create -volname "Munchkin" -srcfolder "dist/Munchkin_DMG" -ov -format UDZO "Munchkin.dmg"`

Install Instructions for Recipients (no notarization)
- Copy to /Applications.
- First run: Right‑click → Open → Open (or allow in Settings → Privacy & Security).
- If quarantined: `xattr -dr com.apple.quarantine "/Applications/Munchkin.app"`.
