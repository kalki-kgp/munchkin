import Foundation
import AppKit

final class Coordinator: ClipboardMonitorDelegate {
    enum State { case idle, accumulating, inFlight, paused }

    private(set) var state: State = .idle { didSet { onStateChange?(state) } }
    var onStateChange: ((State) -> Void)?

    private let settings: SettingsStore
    private let clipboard: ClipboardMonitor

    private var accumulator: String = ""
    private var nextBatch: String = ""
    private var quietTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "dev.munchkin.coordinator")

    // Used for stealth mode indicator: show 'R' for a short time after response
    private(set) var responseReadyUntil: Date?

    init(settings: SettingsStore, clipboard: ClipboardMonitor) {
        self.settings = settings
        self.clipboard = clipboard
        self.clipboard.delegate = self
    }

    func start() {
        updateActiveState()
    }

    // Expose model refresh for UI
    func refreshModels(completion: @escaping (Result<[String], Error>) -> Void) {
        currentClient().listModels { [weak self] result in
            switch result {
            case .success(let models):
                // Update settings list on main queue for UI safety
                DispatchQueue.main.async { self?.settings.availableModels = models }
            case .failure:
                break
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func currentClient() -> LLMClient {
        switch settings.provider {
        case .nebius: return NebiusClient(settings: settings)
        case .openai: return OpenAIClient(settings: settings)
        case .anthropic: return AnthropicClient(settings: settings)
        case .groq: return GroqClient(settings: settings)
        }
    }

    private func updateActiveState() {
        if settings.isActive {
            if state == .paused { state = .idle }
            clipboard.start()
        } else {
            clipboard.stop()
            cancelQuietTimer()
            if state != .inFlight { state = .paused }
        }
    }

    // Exposed to status menu
    var canSendNow: Bool { state == .accumulating && !accumulator.isEmpty }
    func sendNow() { queue.async { self.triggerSendIfPossible() } }

    // MARK: ClipboardMonitorDelegate
    func clipboardDidCopyText(_ text: String) {
        queue.async { [weak self] in self?.handleCopy(text) }
    }

    private func handleCopy(_ text: String) {
        guard settings.isActive else { return }
        if state == .paused { state = .idle }

        // If in-flight, queue for next cycle
        if state == .inFlight {
            append(&nextBatch, text: text)
            return
        }

        // Ignore very short copies if configured
        if text.trimmingCharacters(in: .whitespacesAndNewlines).count < settings.ignoreShortCopyBelow { return }

        // Idle/Accumulating
        if state == .idle { state = .accumulating }
        append(&accumulator, text: text)
        restartQuietTimer()
    }

    private func append(_ target: inout String, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if target.isEmpty { target = clean }
        else { target += settings.delimiter + clean }
        if target.count > settings.maxChars {
            // Truncate oldest part
            target = String(target.suffix(settings.maxChars))
        }
    }

    private func restartQuietTimer() {
        cancelQuietTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + settings.quietSeconds)
        timer.setEventHandler { [weak self] in self?.triggerSendIfPossible() }
        timer.resume()
        quietTimer = timer
    }

    private func cancelQuietTimer() {
        quietTimer?.cancel()
        quietTimer = nil
    }

    private func triggerSendIfPossible() {
        guard state == .accumulating, !accumulator.isEmpty else { return }
        let payload = accumulator
        accumulator = ""
        cancelQuietTimer()
        state = .inFlight

        let sys = settings.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let sysToUse = (settings.useSystemPrompt && !sys.isEmpty) ? sys : nil
        let redacted = redactIfNeeded(payload)
        currentClient().send(prompt: redacted, systemPrompt: sysToUse) { [weak self] result in
            guard let self = self else { return }
            self.queue.async {
                switch result {
                case .success(let text):
                    ClipboardMonitor.writeClipboard(text)
                    self.clipboard.recordSelfWrite(text)
                    // Mark response ready window (5 seconds)
                    self.responseReadyUntil = Date().addingTimeInterval(5)
                    self.onStateChange?(self.state)
                case .failure:
                    // Keep nextBatch if any; nothing else to do
                    break
                }

                if !self.nextBatch.isEmpty && self.settings.isActive {
                    self.accumulator = self.nextBatch
                    self.nextBatch = ""
                    self.state = .accumulating
                    self.restartQuietTimer()
                } else {
                    self.nextBatch = ""
                    self.state = self.settings.isActive ? .idle : .paused
                }
            }
        }
    }

    // Simple local redaction filters
    private func redactIfNeeded(_ input: String) -> String {
        var out = input
        if settings.redactEmails {
            out = out.replacingOccurrences(of: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", with: "<email>", options: [.regularExpression, .caseInsensitive])
        }
        if settings.redactURLs {
            out = out.replacingOccurrences(of: "https?://[A-Za-z0-9./?=&_%:-]+", with: "<url>", options: [.regularExpression])
        }
        if settings.redactNumbers {
            out = out.replacingOccurrences(of: "\\b\\d{3,}\\b", with: "<num>", options: [.regularExpression])
        }
        return out
    }
}
