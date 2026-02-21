import SwiftUI
import AVFoundation
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var permissions: PermissionsManager
    @EnvironmentObject private var config: ConfigManager

    @State private var deepgramKeyInput = ""
    private let permissionRefreshTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [TerminalTheme.background, TerminalTheme.backgroundSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                header
                deepgramSection
                permissionsSection
                footerSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .padding(.top, 12)
        }
        .frame(width: 500, height: 376)
        .onAppear {
            permissions.refresh()
            config.refresh()
        }
        .onReceive(permissionRefreshTimer) { _ in
            guard !permissions.microphoneGranted || !permissions.accessibilityGranted else { return }
            permissions.refresh()
            reconcileRuntimePermissionError()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
            reconcileRuntimePermissionError()
        }
    }

    private func reconcileRuntimePermissionError() {
        guard let lastError = appState.lastError else { return }
        guard lastError.contains("permission") else { return }
        if permissions.microphoneGranted && permissions.accessibilityGranted {
            appState.clearError()
            appState.statusText = "Idle"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("$ txtin")
                .font(.terminal(18, weight: .bold))
                .foregroundStyle(TerminalTheme.textPrimary)
            Text("opt+q :: hold to talk -> release to paste")
                .font(.terminal(10))
                .foregroundStyle(TerminalTheme.textSecondary)
        }
    }

    private var deepgramSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("[deepgram_api_key]")
                .font(.terminal(11, weight: .bold))
                .foregroundStyle(TerminalTheme.textPrimary)

            if config.hasDeepgramKey {
                HStack {
                    Text(config.maskedDeepgramKey() ?? "••••")
                        .font(.terminal(10, weight: .semibold))
                        .foregroundStyle(TerminalTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    Button("DELETE") {
                        config.deleteDeepgramAPIKey()
                    }
                    .buttonStyle(TerminalActionButtonStyle(isPrimary: false))
                }
            } else {
                HStack {
                    SecureField("Enter Deepgram API key", text: $deepgramKeyInput)
                        .font(.terminal(10))
                        .foregroundStyle(TerminalTheme.textPrimary)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(TerminalTheme.panelSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(TerminalTheme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                    Button("SAVE") {
                        config.setDeepgramAPIKey(deepgramKeyInput)
                        deepgramKeyInput = ""
                    }
                    .buttonStyle(TerminalActionButtonStyle(isPrimary: true))
                    .disabled(deepgramKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            HStack(spacing: 4) {
                Text("language")
                    .font(.terminal(9))
                    .foregroundStyle(TerminalTheme.textSecondary)

                Spacer()

                Picker("", selection: languageBinding) {
                    Text("AUTO").tag("auto")
                    Text("RU").tag("ru")
                    Text("EN").tag("en")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 158)
                .font(.terminal(9, weight: .semibold))
                .colorScheme(.light)
            }
            .padding(.top, 4)
        }
        .terminalPanel()
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("[permissions]")
                .font(.terminal(11, weight: .bold))
                .foregroundStyle(TerminalTheme.textPrimary)

            PermissionRow(
                title: "Microphone",
                description: "Required for voice recording",
                granted: permissions.microphoneGranted,
                actionTitle: permissions.microphoneGranted ? "Granted" : "Open"
            ) {
                permissions.requestMicrophoneAccess()
            }

            PermissionRow(
                title: "Accessibility",
                description: "Required for global hotkey and text insertion",
                granted: permissions.accessibilityGranted,
                actionTitle: permissions.accessibilityGranted ? "Granted" : "Open"
            ) {
                permissions.requestAccessibilityAccess()
            }

            if !permissions.accessibilityGranted {
                Text("if app is not in list: click '+' in accessibility settings and select txtin.app from opened finder window")
                    .font(.terminal(8))
                    .foregroundStyle(TerminalTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .terminalPanel()
    }

    private var footerSection: some View {
        HStack {
            Spacer()
            Button("QUIT") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(TerminalActionButtonStyle(isPrimary: false))
        }
        .terminalPanel()
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { config.transcriptionLanguage },
            set: { config.setTranscriptionLanguage($0) }
        )
    }
}
