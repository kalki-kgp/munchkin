# 🪄 Munchkin — Clipboard → LLM → Clipboard (macOS)

**Munchkin** is a lightweight, menubar-only macOS app developed by Kalki that quietly watches your clipboard, groups multiple quick copies into one message, sends them to your favorite LLM provider (Nebius, OpenAI, Anthropic, or Groq), and then writes the response *right back* to your clipboard — so you can paste instantly.

Think of it as a little helper that "munches" your copied text, feeds it to an AI, and hands you a fresh answer — automatically.

---

## ✨ Key Features

- 🧩 **Smart Clipboard Accumulation**  
  Copies made within 5 seconds are combined into one message (with a configurable delimiter).

- ⚡ **Hands-Free LLM Querying**  
  After 5 seconds of quiet, Munchkin sends the accumulated text to your chosen provider.

- 📋 **Instant Response to Clipboard**  
  As soon as the LLM responds, Munchkin replaces your clipboard with the answer — ready to paste.

- 🧠 **Supports Multiple Providers**  
  - [Nebius](https://studio.nebius.com)  
  - [OpenAI](https://platform.openai.com)  
  - [Anthropic](https://anthropic.com)  
  - [Groq](https://groq.com)

- 🔒 **Privacy-Focused**  
  - Only processes clipboard data while "Active"  
  - API keys stored securely in the macOS Keychain  
  - No external logging or analytics

- 🧭 **Stealth Mode**  
  Minimal menubar indicator (I/A/⏳/⏸/R) for power users.

- 🧰 **Configurable System Prompt, Model, and Trigger**

---

## 🛠️ Installation (Developers)

### Prerequisites
- macOS 13+  
- [Xcode](https://developer.apple.com/xcode/) (from Mac App Store)  
- API key(s) for at least one provider

### Setup

```bash
git clone https://github.com/<your-username>/Munchkin.git
cd Munchkin
open Munchkin.xcodeproj
```

Then:

1. In Xcode → Build & Run (⌘R)
2. The app icon will appear in your menu bar (no Dock icon).
3. Choose your provider and set API key(s) via the menu.
4. Enable "Active" and start copying text!

---

## 🧩 Configuration

| Setting | Description |
|---------|-------------|
| Active | Toggles whether clipboard monitoring is on |
| Provider | Choose Nebius / OpenAI / Anthropic / Groq |
| Model | Select a model (refreshable per provider) |
| System Prompt | Optional; edit or disable |
| Delimiter | Text used between joined clipboard items |
| Send Now | Manually send immediately |
| Stealth Mode | Compact indicator (for minimal UI) |

---

## 🧪 Packaging (without Apple Developer Account)

### Option A – ZIP

```bash
xcodebuild -configuration Release
cd build/Release
ditto -c -k --keepParent "Munchkin.app" "Munchkin.zip"
```

### Option B – DMG

```bash
mkdir -p dist/Munchkin_DMG && \
cp -R "Munchkin.app" dist/Munchkin_DMG/ && \
ln -s /Applications dist/Munchkin_DMG/Applications && \
hdiutil create -volname "Munchkin" -srcfolder "dist/Munchkin_DMG" -ov -format UDZO "Munchkin.dmg"
```

If macOS flags it as unverified:

```bash
xattr -dr com.apple.quarantine "/Applications/Munchkin.app"
```

---

## 🖼️ Icon & Branding

App icon designed to match modern macOS (2025) themes.

- Rounded-rect teal background with a white clipboard silhouette and a "bite" mark.
- 3 small orange dots symbolize text accumulation & processing.

---

## 🤝 Contributing

Pull requests and feature suggestions are warmly welcome!

Before submitting:
- Follow Swift & SwiftUI best practices.
- Keep the code modular and sandbox-friendly.
- Test locally before PR.

---

## 🪪 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

### MIT License

```text
MIT License

Copyright (c) 2025 Kalki

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙌 Credits

Built with ❤️ by Kalki

Inspired by the simplicity of automation and curiosity of tiny AI helpers — the munchkin spirit.

---

## 📜 About

Munchkin is a small macOS utility that lives quietly in your menubar. It observes your clipboard, gathers snippets, and sends them to your chosen AI model to generate a quick, intelligent response. Think of it as your background assistant for contextual LLM queries — tiny, private, and fast.

---

## 🧾 App Menu "About" Section

Use this concise, user-facing version in your app:

> **Munchkin**  
> Clipboard → LLM → Clipboard  
>  
> A tiny macOS menubar helper that collects your copied text, sends it to your favorite AI model (Nebius, OpenAI, Anthropic, or Groq), and puts the answer back in your clipboard — automatically.  
>  
> © 2025 Kalki  
> Licensed under the MIT License.

---

## 🚀 Quick Start Guide

1. **Install & Launch**: Build in Xcode and run the app
2. **Set API Key**: Click the menubar icon and configure your preferred LLM provider
3. **Activate**: Toggle "Active" mode in the menu
4. **Copy Text**: Copy any text you want to process
5. **Wait 5 Seconds**: Munchkin automatically sends your text to the LLM
6. **Paste Result**: The AI response replaces your clipboard — just paste anywhere!

Happy munching! 🧠✨
