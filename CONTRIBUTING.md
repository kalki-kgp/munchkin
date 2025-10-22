# 🤝 Contributing to Munchkin

First off, thank you for taking the time to contribute! 🎉  
Your help makes **Munchkin** better for everyone — whether you're fixing bugs, improving docs, or adding new features.

---

## 💡 How to Contribute

### 1. Fork the Repository
Click **Fork** on the top right of [the main repo](https://github.com/kalki-kgp/Munchkin).

Then clone your fork:
```bash
git clone https://github.com/kalki-kgp/Munchkin.git
cd Munchkin
```

### 2. Create a Feature Branch
```bash
git checkout -b feature/your-feature-name
```

### 3. Make Your Changes

Follow Swift / SwiftUI best practices:

- Keep components modular and readable.
- Use descriptive commit messages.
- Ensure clipboard behavior stays non-intrusive.
- Avoid adding dependencies unless essential.

### 4. Test Before Submitting

Make sure your code:

- Builds successfully in Xcode.
- Doesn't break menu items or event monitoring.
- Respects privacy (no logs or network leaks).

### 5. Commit and Push
```bash
git add .
git commit -m "Add: short description of change"
git push origin feature/your-feature-name
```

### 6. Open a Pull Request

- Go to your fork on GitHub → **New Pull Request**
- Describe what you've changed and why. Include screenshots if it's UI-related.

---

## 🧠 Code Style Guidelines

- Follow [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).
- Use spaces, not tabs (2-space indentation).
- Prefer descriptive variable and function names.
- Avoid long functions — keep things composable.

---

## 🧪 Testing Suggestions

Try these manual test cases:

- Copy multiple text snippets quickly → confirm they combine and send after 5s.
- Check new provider API logic.
- Confirm clipboard loop guard works.
- Verify "Active" toggle, "Stealth Mode", and "Send Now".

---

## 💬 Feature Ideas?

Open a [GitHub Issue](https://github.com/kalki-kgp/Munchkin/issues) with the tag:

- `enhancement` for new ideas
- `bug` for problems
- `docs` for documentation improvements

---

## 🛡️ License Reminder

By contributing to this project, you agree that your contributions will be licensed under the same MIT License that covers the project.

---

**Thank you for helping grow Munchkin —  
the tiniest, smartest clipboard muncher for macOS!** 🪄