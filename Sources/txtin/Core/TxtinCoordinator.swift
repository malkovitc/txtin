import Foundation
import AppKit
import AVFoundation

@MainActor
final class TxtinCoordinator: ObservableObject {
    static let shared = TxtinCoordinator(
        appState: .shared,
        permissions: .shared,
        config: .shared
    )

    private let appState: AppState
    private let permissions: PermissionsManager
    private let config: ConfigManager
    private let recorder = VoiceRecorder()
    private let indicator = RecordingIndicatorManager.shared

    private var targetAppForInsertion: NSRunningApplication?
    private var lastExternalAppForInsertion: NSRunningApplication?
    private var transcriptionTask: Task<Void, Never>?
    private var transcriptionGeneration = 0
    private var recordingStartedAt: Date?
    private var workspaceObserver: NSObjectProtocol?
    private var hotkeyReadyAt = Date.distantPast

    init(appState: AppState, permissions: PermissionsManager, config: ConfigManager) {
        self.appState = appState
        self.permissions = permissions
        self.config = config

        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastExternalAppForInsertion = frontApp
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            Task { @MainActor [weak self] in
                self?.lastExternalAppForInsertion = app
            }
        }
    }

    deinit {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    func setupHotkey() {
        HotkeyManager.shared.onPressed = { [weak self] in
            Task { @MainActor in
                guard let self, Date() >= self.hotkeyReadyAt else { return }
                self.startRecording()
            }
        }
        HotkeyManager.shared.onReleased = { [weak self] in
            Task { @MainActor in
                guard let self, Date() >= self.hotkeyReadyAt else { return }
                self.stopAndTranscribe()
            }
        }

        hotkeyReadyAt = Date().addingTimeInterval(1.25)
        let registered = HotkeyManager.shared.registerOptionQ()
        if !registered {
            appState.setError(HotkeyManager.shared.lastRegistrationError ?? "Failed to register Option+Q")
        }
    }

    func toggleRecording() {
        if appState.isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard !appState.isRecording else { return }

        transcriptionTask?.cancel()
        transcriptionTask = nil
        transcriptionGeneration += 1
        indicator.hide()

        appState.clearError()
        permissions.refresh()
        reconcilePermissionErrorIfNeeded()

        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard microphoneStatus == .authorized else {
            appState.setError("Microphone permission is required")
            permissions.requestMicrophoneAccess()
            return
        }

        let accessibilityGranted = AXIsProcessTrusted()
        guard accessibilityGranted else {
            appState.setError("Accessibility permission is required for hotkeys and text insertion")
            permissions.requestAccessibilityAccess()
            return
        }

        saveTargetApp()

        do {
            _ = try recorder.start()
            recordingStartedAt = Date()
            appState.isRecording = true
            appState.statusText = "Recording..."
            indicator.showRecording()
        } catch {
            appState.setError(error.localizedDescription)
            indicator.hide()
        }
    }

    func stopAndTranscribe() {
        guard appState.isRecording else { return }

        appState.clearError()

        let audioFileURL: URL
        do {
            audioFileURL = try recorder.stop()
        } catch {
            appState.setError(error.localizedDescription)
            appState.isRecording = false
            indicator.hide()
            return
        }

        if let startedAt = recordingStartedAt, Date().timeIntervalSince(startedAt) < 0.35 {
            appState.setError("Hold Option+Q while speaking, then release")
            appState.isRecording = false
            appState.statusText = "Error"
            indicator.hide()
            try? FileManager.default.removeItem(at: audioFileURL)
            return
        }

        appState.isRecording = false
        appState.statusText = "Transcribing..."
        indicator.showTranscribing()

        guard let apiKey = config.deepgramAPIKey(), !apiKey.isEmpty else {
            appState.setError("Deepgram API key is missing")
            indicator.hide()
            try? FileManager.default.removeItem(at: audioFileURL)
            return
        }

        let insertionTarget = targetAppForInsertion
        let generation = transcriptionGeneration + 1
        transcriptionGeneration = generation

        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            defer { try? FileManager.default.removeItem(at: audioFileURL) }

            do {
                guard let self else { return }
                let language = self.config.resolvedTranscriptionLanguage()
                let text = try await Task.detached(priority: .userInitiated) {
                    try await DeepgramTranscriptionService.shared.transcribe(
                        fileURL: audioFileURL,
                        apiKey: apiKey,
                        language: language
                    )
                }.value
                try Task.checkCancellation()
                await self.insertTranscript(text, targetApp: insertionTarget, generation: generation)
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    guard let self, self.transcriptionGeneration == generation else { return }
                    self.appState.statusText = "Idle"
                    self.indicator.hide()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, self.transcriptionGeneration == generation else { return }
                    self.appState.setError(error.localizedDescription)
                    self.indicator.hide()
                }
            }
        }
    }

    private func saveTargetApp() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        if let frontApp, frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetAppForInsertion = frontApp
            lastExternalAppForInsertion = frontApp
        } else {
            targetAppForInsertion = lastExternalAppForInsertion
        }
    }

    private func insertTranscript(_ text: String, targetApp: NSRunningApplication?, generation: Int) async {
        guard transcriptionGeneration == generation else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appState.setError("No speech detected")
            indicator.hide()
            return
        }

        let resolvedTarget = targetApp ?? lastExternalAppForInsertion
        if let resolvedTarget, !resolvedTarget.isTerminated {
            resolvedTarget.unhide()
            _ = resolvedTarget.activate(options: [])
        }

        try? await Task.sleep(nanoseconds: 250_000_000)
        guard transcriptionGeneration == generation else { return }

        let insertionResult = await TextInsertionService.shared.insertText(trimmed)
        guard transcriptionGeneration == generation else { return }

        switch insertionResult {
        case .inserted:
            appState.clearError()
            appState.statusText = "Inserted"
        case .copiedToClipboard(let message):
            appState.setError(message)
        case .failed(let message):
            appState.setError(message)
        }

        targetAppForInsertion = nil
        indicator.hide()
    }

    private func reconcilePermissionErrorIfNeeded() {
        guard let lastError = appState.lastError else { return }
        guard lastError.contains("permission") else { return }
        if permissions.microphoneGranted && permissions.accessibilityGranted {
            appState.clearError()
            appState.statusText = "Idle"
        }
    }
}
