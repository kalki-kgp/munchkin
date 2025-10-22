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

    // Keep last response lines for manual overlay
    private var lastResponseLines: [String] = []

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
        currentClient().send(prompt: payload, systemPrompt: sysToUse) { [weak self] result in
            guard let self = self else { return }
            self.queue.async {
                switch result {
                case .success(let text):
                    ClipboardMonitor.writeClipboard(text)
                    self.clipboard.recordSelfWrite(text)
                    // Mark response ready window (5 seconds)
                    self.responseReadyUntil = Date().addingTimeInterval(5)
                    self.onStateChange?(self.state)

                    // Prepare overlay lines
                    self.lastResponseLines = self.makeLines(from: text)
                    if self.settings.overlayAutoShow {
                        ResponseOverlayManager.shared.show(lines: self.lastResponseLines, settings: self.settings) {
                            // On close by inactivity or double click -> go idle if not in-flight
                            if self.state != .inFlight { self.state = self.settings.isActive ? .idle : .paused }
                        }
                    }
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

    // Show last response overlay manually
    func showOverlay() {
        guard !lastResponseLines.isEmpty else { return }
        ResponseOverlayManager.shared.show(lines: lastResponseLines, settings: settings) {
            if self.state != .inFlight { self.state = self.settings.isActive ? .idle : .paused }
        }
    }

    // Split into single-line units, soft-wrapping by approximate character width
    private func makeLines(from text: String) -> [String] {
        let rawLines = text.components(separatedBy: .newlines)
        let avgCharWidth: CGFloat = 7.0 // approx for 14pt; good enough for paging by chars
        let maxChars = max(10, Int(CGFloat(settings.overlayWidth) / avgCharWidth))
        var out: [String] = []
        for raw in rawLines {
            let words = raw.split(separator: " ", omittingEmptySubsequences: false)
            var current = ""
            for w in words {
                if current.isEmpty {
                    current = String(w)
                } else if current.count + 1 + w.count <= maxChars {
                    current += " " + w
                } else {
                    out.append(current)
                    current = String(w)
                }
            }
            if !current.isEmpty { out.append(current) }
            if raw.isEmpty { out.append("") }
        }
        return out
    }
}
