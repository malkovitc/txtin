import AppKit

@MainActor
final class RecordingIndicatorManager {
    static let shared = RecordingIndicatorManager()

    private var panel: NSPanel?
    private let label = NSTextField(labelWithString: "Recording...")
    private let dotView = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))

    private init() {}

    func showRecording() {
        show(text: "Recording...")
    }

    func showTranscribing() {
        show(text: "Transcribing...")
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func show(text: String) {
        let panel = ensurePanel()
        label.stringValue = text
        positionPanel(panel)
        panel.orderFrontRegardless()
    }

    private func ensurePanel() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
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

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 44))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        content.layer?.cornerRadius = 12

        dotView.wantsLayer = true
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        dotView.layer?.cornerRadius = 5
        dotView.frame.origin = NSPoint(x: 14, y: 17)

        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.frame = NSRect(x: 32, y: 11, width: 170, height: 22)

        content.addSubview(dotView)
        content.addSubview(label)
        panel.contentView = content

        self.panel = panel
        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - (panel.frame.width / 2)
        let y = visible.minY + 24
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
