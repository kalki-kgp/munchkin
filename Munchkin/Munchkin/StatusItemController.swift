import AppKit

final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let coordinator: Coordinator
    private let settings: SettingsStore
    private var isRefreshing = false
    private var clockTimer: Timer?

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.locale = .autoupdatingCurrent
        return df
    }()

    init(coordinator: Coordinator, settings: SettingsStore) {
        self.coordinator = coordinator
        self.settings = settings
    }

    func setup() {
        updateButtonTitle()
        rebuildMenu()
        coordinator.onStateChange = { [weak self] _ in self?.rebuildMenu() }

        // Update menubar clock every second without rebuilding the menu
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateButtonTitle()
        }
        if let t = clockTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func rebuildMenu() {
        DispatchQueue.main.async { [weak self] in
            self?._rebuildMenuOnMainThread()
        }
    }
    
    private func _rebuildMenuOnMainThread() {
        updateButtonTitle()
        let menu = NSMenu()

        let stateItem = NSMenuItem(title: "State: \(stateText())", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        // Provider submenu
        let providerMenu = NSMenu()
        for p in ModelProvider.allCases {
            let item = NSMenuItem(title: p.rawValue, action: #selector(selectProvider(_:)), keyEquivalent: "")
            item.target = self
            item.state = (p == settings.provider) ? .on : .off
            providerMenu.addItem(item)
        }
        let providerItem = NSMenuItem(title: "Provider", action: nil, keyEquivalent: "")
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)

        let activeItem = NSMenuItem(title: settings.isActive ? "Active ✓" : "Active", action: #selector(toggleActive), keyEquivalent: "")
        activeItem.target = self
        menu.addItem(activeItem)

        let stealthItem = NSMenuItem(title: settings.stealthMode ? "Stealth Mode ✓" : "Stealth Mode", action: #selector(toggleStealth), keyEquivalent: "")
        stealthItem.target = self
        menu.addItem(stealthItem)

        let sendNowItem = NSMenuItem(title: "Send Now", action: #selector(sendNow), keyEquivalent: "")
        sendNowItem.target = self
        sendNowItem.isEnabled = coordinator.canSendNow
        menu.addItem(sendNowItem)

        let modelMenu = NSMenu()
        for model in settings.availableModels {
            let item = NSMenuItem(title: model, action: #selector(selectModel(_:)), keyEquivalent: "")
            item.target = self
            item.state = (model == settings.model) ? .on : .off
            modelMenu.addItem(item)
        }
        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        modelItem.submenu = modelMenu
        menu.addItem(modelItem)

        let refreshItem = NSMenuItem(title: isRefreshing ? "Refreshing Models…" : "Refresh Models", action: #selector(refreshModels), keyEquivalent: "")
        refreshItem.target = self
        refreshItem.isEnabled = !isRefreshing
        menu.addItem(refreshItem)

        menu.addItem(.separator())
        // System Prompt
        let sysPreview = settings.systemPrompt.isEmpty ? "(empty)" : String(settings.systemPrompt.prefix(40)) + (settings.systemPrompt.count > 40 ? "…" : "")
        let sysInfo = NSMenuItem(title: "System Prompt: \(sysPreview)", action: nil, keyEquivalent: "")
        sysInfo.isEnabled = false
        menu.addItem(sysInfo)
        let toggleSys = NSMenuItem(title: settings.useSystemPrompt ? "Use System Prompt ✓" : "Use System Prompt", action: #selector(toggleSystemPrompt), keyEquivalent: "")
        toggleSys.target = self
        menu.addItem(toggleSys)
        let setSysItem = NSMenuItem(title: "Set System Prompt…", action: #selector(setSystemPrompt), keyEquivalent: "")
        setSysItem.target = self
        menu.addItem(setSysItem)

        menu.addItem(.separator())
        let setKeyItem = NSMenuItem(title: "Set \(settings.provider.rawValue) API Key…", action: #selector(setAPIKey), keyEquivalent: "")
        setKeyItem.target = self
        menu.addItem(setKeyItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleActive() {
        settings.isActive.toggle()
        coordinator.start()
        rebuildMenu()
    }

    @objc private func toggleStealth() {
        settings.stealthMode.toggle()
        rebuildMenu()
    }

    @objc private func sendNow() {
        coordinator.sendNow()
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        settings.model = sender.title
        rebuildMenu()
    }

    @objc private func selectProvider(_ sender: NSMenuItem) {
        guard let selected = ModelProvider.allCases.first(where: { $0.rawValue == sender.title }) else { return }
        settings.provider = selected
        // Reset models to defaults for new provider handled in settings.provider setter
        rebuildMenu()
    }

    @objc private func refreshModels() {
        isRefreshing = true
        rebuildMenu()
        coordinator.refreshModels { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRefreshing = false
            switch result {
            case .success(let models):
                self.settings.availableModels = models
            case .failure(let error):
                let alert = NSAlert()
                alert.messageText = "Failed to refresh models"
                var info = error.localizedDescription
                let nsErr = error as NSError
                if nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorCannotFindHost {
                    info += "\n\nHint: In Xcode → Target → Signing & Capabilities, enable App Sandbox ‘Outgoing Connections (Client)’ or disable App Sandbox during development."
                }
                alert.informativeText = info
                alert.runModal()
            }
                self.rebuildMenu()
            }
        }
    }

    @objc private func setAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Enter \(settings.provider.rawValue) API Key"
        alert.informativeText = "Your key will be stored in Keychain."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let secureField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        secureField.stringValue = settings.apiKey(for: settings.provider) ?? ""
        alert.accessoryView = secureField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let key = secureField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.setApiKey(key.isEmpty ? nil : key, for: settings.provider)
        }
    }

    @objc private func toggleSystemPrompt() {
        settings.useSystemPrompt.toggle()
        rebuildMenu()
    }

    @objc private func setSystemPrompt() {
        let alert = NSAlert()
        alert.messageText = "Set System Prompt"
        alert.informativeText = "This prompt will be sent with every request (as a system message)."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 160))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 350, height: 160))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = settings.systemPrompt
        scroll.documentView = textView
        alert.accessoryView = scroll

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            settings.systemPrompt = textView.string
            rebuildMenu()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func stateText() -> String {
        switch coordinator.state {
        case .idle: return "Idle"
        case .accumulating: return "Accumulating"
        case .inFlight: return "In Flight"
        case .paused: return "Paused"
        }
    }

    private func updateButtonTitle() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let button = self.statusItem.button {
                if self.settings.stealthMode {
                    // Determine if we should show 'R' window
                    var text: String
                    if let until = self.coordinator.responseReadyUntil, Date() < until {
                        text = "R"
                    } else {
                        switch self.coordinator.state {
                        case .idle: text = "I"
                        case .accumulating: text = "A"
                        case .inFlight: text = "⏳"
                        case .paused: text = "⏸"
                        }
                    }
                    button.title = text
                    button.toolTip = "Munchkin — \(self.stateText())"
                } else {
                    let suffix: String
                    switch self.coordinator.state {
                    case .idle: suffix = ""
                    case .accumulating: suffix = " A"
                    case .inFlight: suffix = " ⏳"
                    case .paused: suffix = " ⏸"
                    }
                    let time = Self.timeFormatter.string(from: Date())
                    button.title = "🧩" + suffix + "  " + time
                    button.toolTip = "Munchkin — \(self.stateText())"
                }
            }
        }
    }
}
