Munchkin — Background Clipboard → Nebius → Clipboard (macOS)

Overview
- Menubar-only app (no Dock icon) that watches your clipboard.
- It accumulates copied text until there’s 5 seconds of no new copies, then sends the combined text to Nebius (OpenAI-compatible API).
- As soon as a response arrives, it writes the response back to the clipboard so you can paste it immediately.

Key Behaviors
- Accumulation window: 5 seconds of quiet after the last copy event triggers a send.
- Multiple quick copies are joined with a configurable delimiter (default: blank line).
- Loop guard prevents self-triggering when the app writes the clipboard.
- If you copy while a request is in-flight, those new copies will be queued for the next cycle.

What You Need
1) Xcode installed (from the Mac App Store).
2) A Nebius API key (set in Keychain via the app) and a model name (e.g., deepseek-ai/DeepSeek-V3-0324-fast).

Project Setup in Xcode (one-time)
1. Open Xcode → File → New → Project…
2. Choose “App” under the macOS tab. Click Next.
3. Product Name: Munchkin; Interface: SwiftUI; Language: Swift. Click Next.
4. Save the project (anywhere). Quit Xcode temporarily.
5. In Finder, drag the contents of this repository’s `Munchkin` folder into your Xcode project’s root group:
   - Add: `MunchkinApp.swift`, `StatusItemController.swift`, `ClipboardMonitor.swift`, `Coordinator.swift`, `NebiusClient.swift`, `KeychainStore.swift`, `Settings.swift`, `Info.plist`.
   - When prompted, ensure “Copy items if needed” is checked, and your app target is selected.
6. Set LSUIElement so it runs as a menubar app:
   - In Xcode, select your app target → Info tab.
   - Add a new key to the Info section: `Application is agent (UIElement)` with value `YES`.
   - Alternatively, merge the provided `Info.plist` content into your target’s Info.plist and ensure LSUIElement is true.
7. Capabilities (optional, if you enable App Sandbox):
   - If App Sandbox is enabled, also enable Outgoing Network Connections.
8. Build & Run (Cmd+R). The app shows as an icon in the macOS menu bar (no Dock icon).

First Run
- Click the Munchkin menu bar icon → Settings → “Set Nebius API Key…”, paste your key.
- Ensure “Active” is checked in the menu.
- Copy some text; after 5 seconds of no new copies, the app sends the combined text to OpenAI and replaces your clipboard with the response.

Menu Items
- Active: Toggle processing on/off.
- Send Now: Immediately send the current accumulation without waiting.
- Model: Choose a model (predefined list). You can fetch your available models via:
  `curl https://api.studio.nebius.com/v1/models -H "Authorization: Bearer YOUR_NEBIUS_API_KEY"`
- Set OpenAI API Key…: Store your key in Keychain.
- Quit.

Privacy Notes
- The app only sends plaintext clipboard data you copy while Active.
- API key is stored in Keychain.
- Console logs are minimal by default and can be made verbose in code.

Troubleshooting
- If you don’t see the menubar icon, confirm LSUIElement is set to YES and the app built successfully.
- If requests fail, verify your Nebius API key and network connectivity.
- If the app seems to re-trigger on its own writes, verify the loop guard is enabled (it is, by default) and avoid external clipboard managers that rewrite content.
