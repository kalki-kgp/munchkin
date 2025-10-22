import AppKit
import CryptoKit

protocol ClipboardMonitorDelegate: AnyObject {
    func clipboardDidCopyText(_ text: String)
}

final class ClipboardMonitor {
    weak var delegate: ClipboardMonitorDelegate?

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastWrittenDigest: Data?
    private var lastWriteAt: Date?

    // Guard self-writes for this window (ms)
    private let selfWriteGrace: TimeInterval = 1.0

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // Called by Coordinator when we write to the clipboard
    func recordSelfWrite(_ text: String) {
        lastWrittenDigest = Self.digest(of: text)
        lastWriteAt = Date()
    }

    private func poll() {
        let pb = NSPasteboard.general
        if pb.changeCount == lastChangeCount { return }
        lastChangeCount = pb.changeCount

        guard let s = pb.string(forType: .string), !s.isEmpty else { return }

        // Loop guard: if the change matches our last write within grace, ignore
        if let lw = lastWrittenDigest, let t = lastWriteAt, Date().timeIntervalSince(t) <= selfWriteGrace {
            if lw == Self.digest(of: s) { return }
        }

        delegate?.clipboardDidCopyText(s)
    }

    static func digest(of text: String) -> Data {
        Data(SHA256.hash(data: Data(text.utf8)))
    }

    static func writeClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

