import AppKit
import SwiftUI

// MARK: - State

private enum IndicatorState {
    case recording, transcribing
}

// MARK: - View Model

@MainActor
private final class IndicatorViewModel: ObservableObject {
    @Published var state: IndicatorState = .recording
}

// MARK: - View

private struct IndicatorView: View {
    @ObservedObject var model: IndicatorViewModel
    @State private var tick = 0

    private let timer = Timer.publish(every: 0.13, on: .main, in: .common).autoconnect()
    private let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    // 17 bars × 3pt + 16 gaps × 2.5pt = 91pt ≈ "processing..." text width in terminal(11)
    private let barCount = 17

    // Each bar gets its OWN frequency — non-harmonic ratios mean they never sync up.
    // This is what makes it look organic rather than like a rolling wave.
    private let barFreqs: [Double] = [
        0.11, 0.23, 0.17, 0.29, 0.13, 0.31, 0.19, 0.37,
        0.07, 0.41, 0.43, 0.09, 0.53, 0.47, 0.61, 0.59, 0.67
    ]
    // Starting phases so bars begin at different heights (not all at zero)
    private let barPhases: [Double] = [
        0.0, 1.8, 0.5, 2.3, 0.9, 2.7, 0.3, 1.5,
        2.1, 0.7, 1.9, 0.4, 2.5, 1.1, 0.8, 2.2, 1.4
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Symbol — normalized to same width so both modes align identically
            indicatorSymbol
                .frame(width: 14, alignment: .center)

            // 3-char label ("rec" / "txt") — monospaced, same width in both modes
            Text(model.state == .recording ? "rec" : "txt")
                .foregroundStyle(TerminalTheme.textSecondary)
                .padding(.leading, 7)

            // Right content — fixed width AND height so both modes are identical size
            rightContent
                .frame(width: 93, height: 16, alignment: .leading)
                .padding(.leading, 10)
        }
        .font(.terminal(11, weight: .semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // Total width: 14 + 14 + 7 + ~20("rec") + 10 + 93 + 14 = ~172pt — fixed for both modes
        .background(TerminalTheme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(TerminalTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onReceive(timer) { _ in tick += 1 }
    }

    // MARK: Left symbol

    @ViewBuilder
    private var indicatorSymbol: some View {
        switch model.state {
        case .recording:
            Circle()
                .fill(TerminalTheme.textSecondary)
                .frame(width: 6, height: 6)
                .opacity(tick % 3 == 0 ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.4), value: tick)
        case .transcribing:
            Text(spinnerFrames[tick % spinnerFrames.count])
                .foregroundStyle(TerminalTheme.textSecondary)
                .transaction { $0.animation = nil }
        }
    }

    // MARK: Right content

    @ViewBuilder
    private var rightContent: some View {
        switch model.state {
        case .recording:
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0 ..< barCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(TerminalTheme.textSecondary)
                        .frame(width: 3, height: barHeight(for: i))
                        .animation(.easeInOut(duration: 0.2), value: tick)
                }
            }

        case .transcribing:
            // 13 monospaced chars wide — same visual width as the bars above
            Text(transcribingText)
                .foregroundStyle(TerminalTheme.textSecondary)
                .fixedSize()
                .transaction { $0.animation = nil }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let t = Double(tick)
        // Each bar: primary oscillation at its own frequency + cross-modulation
        // from a different bar's frequency. Non-harmonic ratios → bars never sync.
        let v1 = sin(t * barFreqs[index] + barPhases[index])
        let v2 = sin(t * barFreqs[(index + 9) % barCount] * 1.3
                     + barPhases[(index + 5) % barCount])
        let v = v1 * 0.6 + v2 * 0.4          // -1 … +1
        return 3.0 + CGFloat((v + 1.0) / 2.0) * 11.0  // 3 … 14 pt
    }

    private var transcribingText: String {
        switch (tick / 3) % 4 {
        case 0: return "processing.  "
        case 1: return "processing.. "
        case 2: return "processing..."
        default: return "processing   "
        }
    }
}

// MARK: - Manager

@MainActor
final class RecordingIndicatorManager {
    static let shared = RecordingIndicatorManager()

    private var panel: NSPanel?
    private let viewModel = IndicatorViewModel()

    private init() {}

    func showRecording() {
        viewModel.state = .recording
        showIfNeeded()
    }

    func showTranscribing() {
        viewModel.state = .transcribing
        showIfNeeded()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - Private

    private func showIfNeeded() {
        let panel = ensurePanel()
        // Only position the panel when transitioning from hidden → visible.
        // Skipping reposition on state changes (rec → transcribing) prevents visual jumps.
        guard !panel.isVisible else {
            panel.orderFrontRegardless()
            return
        }
        positionPanel(panel)
        panel.orderFrontRegardless()
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let hosting = NSHostingView(rootView: IndicatorView(model: viewModel))

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 40),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.contentView = hosting

        self.panel = panel
        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let hosting = panel.contentView as? NSHostingView<IndicatorView> else { return }
        let size = hosting.fittingSize
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - size.width / 2
        let y = visible.minY + 24
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: false)
    }
}
