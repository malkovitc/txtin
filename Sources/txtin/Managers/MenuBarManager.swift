import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    static var shared: MenuBarManager?
    static weak var current: MenuBarManager?

    private let onboardingPopoverShownKey = "txtin.onboarding_popover_shown"
    private let statusItem: NSStatusItem
    private let coordinator: TxtinCoordinator
    private let appState: AppState
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var statusItemRecoveryWorkItem: DispatchWorkItem?

    init(coordinator: TxtinCoordinator, appState: AppState) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.coordinator = coordinator
        self.appState = appState
        super.init()

        Self.shared = self
        Self.current = self
        bindState()
        setupStatusItem()
        setupPopover()
        scheduleStatusItemRecoveryIfNeeded()

        // Some systems create status item lazily right after launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.setupStatusItem()
            self?.applyIcon(isRecording: self?.appState.isRecording ?? false)
            self?.showOnboardingPopoverIfNeeded()
            self?.scheduleStatusItemRecoveryIfNeeded()
        }
    }

    private func bindState() {
        appState.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.updateIcon(isRecording: isRecording)
            }
            .store(in: &cancellables)
    }

    private func setupStatusItem() {
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "txtin"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            applyIcon(isRecording: false)
        }
    }

    private func setupPopover() {
        let content = SettingsView()
            .environmentObject(appState)
            .environmentObject(PermissionsManager.shared)
            .environmentObject(ConfigManager.shared)
            .environmentObject(coordinator)

        let hosting = NSHostingController(rootView: content)
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 500, height: 376)
        popover.behavior = .transient
    }

    private func updateIcon(isRecording: Bool) {
        applyIcon(isRecording: isRecording)
    }

    private func applyIcon(isRecording: Bool) {
        guard let button = statusItem.button else { return }

        let symbolCandidates = isRecording
            ? ["record.circle.fill", "record.circle"]
            : ["waveform", "mic.fill", "wave.3.right"]
        let image = symbolCandidates.compactMap { NSImage(systemSymbolName: $0, accessibilityDescription: "txtin") }.first
        image?.isTemplate = true
        image?.size = NSSize(width: 14, height: 14)
        button.image = image
        button.title = ""
        button.contentTintColor = nil

        if button.image == nil {
            button.title = isRecording ? "●" : "◉"
            button.imagePosition = .noImage
            button.font = .systemFont(ofSize: 14, weight: .semibold)
        } else {
            button.imagePosition = .imageOnly
        }
    }

    private func scheduleStatusItemRecoveryIfNeeded(attempt: Int = 0) {
        statusItemRecoveryWorkItem?.cancel()

        guard statusItem.button == nil, attempt < 20 else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.setupStatusItem()
            self.applyIcon(isRecording: self.appState.isRecording)
            self.scheduleStatusItemRecoveryIfNeeded(attempt: attempt + 1)
        }
        statusItemRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func showOnboardingPopoverIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: onboardingPopoverShownKey) else { return }
        showPopoverAndActivate()
        UserDefaults.standard.set(true, forKey: onboardingPopoverShownKey)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        togglePopover()
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopoverAndActivate()
        }
    }

    func showPopoverAndActivate() {
        NSApp.activate(ignoringOtherApps: true)
        if statusItem.button == nil {
            setupStatusItem()
        }
        guard let button = statusItem.button else { return }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let toggleTitle = appState.isRecording ? "Stop Recording (Option+Q)" : "Start Recording (Option+Q)"
        let toggle = NSMenuItem(title: toggleTitle, action: #selector(toggleRecordingAction), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleRecordingAction() {
        coordinator.toggleRecording()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
