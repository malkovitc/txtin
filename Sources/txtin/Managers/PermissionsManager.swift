import Foundation
import AppKit
import AVFoundation

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published private(set) var microphoneStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published private(set) var accessibilityGranted: Bool = AXIsProcessTrusted()
    private var permissionPollingTask: Task<Void, Never>?

    private init() {}

    var microphoneGranted: Bool {
        microphoneStatus == .authorized
    }

    func refresh() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestMicrophoneAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refresh()
                }
            }
            return
        }

        openMicrophoneSettings()
        startPermissionPolling()
    }

    func requestAccessibilityAccess() {
        NSApp.activate(ignoringOtherApps: true)

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
        revealCurrentAppInFinder()
        startPermissionPolling()
    }

    func openMicrophoneSettings() {
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    func openAccessibilitySettings() {
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func openSystemSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let opened = NSWorkspace.shared.open(url)
        if !opened, let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            _ = NSWorkspace.shared.open(fallback)
        }
    }

    private func revealCurrentAppInFinder() {
        let appURL = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
    }

    private func startPermissionPolling() {
        permissionPollingTask?.cancel()
        permissionPollingTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<30 {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.refresh()
                if self.microphoneGranted && self.accessibilityGranted {
                    return
                }
            }
        }
    }
}
