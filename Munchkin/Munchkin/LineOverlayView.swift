import SwiftUI

struct LineOverlayView: View {
    let lines: [String]
    let fontSize: CGFloat
    let textColor: Color
    let scrollThreshold: CGFloat
    let onClose: () -> Void

    @State private var index: Int = 0
    @State private var lastScrollAt: Date = Date()

    var body: some View {
        ZStack {
            // Transparent background
            Color.clear
            // Single-line black text
            Text(currentLine)
                .font(.system(size: fontSize, weight: .regular, design: .default))
                .foregroundColor(textColor)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: onClose)
        }
        .background(Color.white.opacity(0.001)) // keep hit-testing
        .overlay(ScrollCatcher(onScroll: handleScroll))
        .onAppear { index = 0 }
    }

    private var currentLine: String { lines.isEmpty ? "" : lines[min(max(index, 0), lines.count-1)] }

    @State private var accumulated: CGFloat = 0
    private func handleScroll(_ dy: CGFloat) {
        lastScrollAt = Date()
        accumulated += dy
        while accumulated <= -scrollThreshold { // scrolling down
            index = min(index + 1, max(0, lines.count - 1))
            accumulated += scrollThreshold
        }
        while accumulated >= scrollThreshold { // scrolling up
            index = max(index - 1, 0)
            accumulated -= scrollThreshold
        }
    }
}

// Transparent NSView to capture scroll wheel events and forward to SwiftUI
private struct ScrollCatcher: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void
    func makeNSView(context: Context) -> NSScrollCatcherView { NSScrollCatcherView(onScroll: onScroll) }
    func updateNSView(_ nsView: NSScrollCatcherView, context: Context) {}
}

private final class NSScrollCatcherView: NSView {
    private let onScroll: (CGFloat) -> Void
    init(onScroll: @escaping (CGFloat) -> Void) {
        self.onScroll = onScroll
        super.init(frame: .zero)
        wantsLayer = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Let mouse/tap events pass through to SwiftUI underlay so double-click works
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }

    override func scrollWheel(with event: NSEvent) {
        // Accumulate precise deltas; treat small deltas as one step for trackpads
        onScroll(event.scrollingDeltaY)
    }
}
