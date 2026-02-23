import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isRecording = false
    @Published var statusText = "Idle"
    @Published var lastError: String?

    private init() {}

    func setError(_ message: String) {
        lastError = message
        statusText = "Error"
    }

    func clearError() {
        lastError = nil
    }

    func clearPermissionErrorIfGranted(microphone: Bool, accessibility: Bool) {
        guard let lastError, lastError.contains("permission") else { return }
        if microphone && accessibility {
            clearError()
            statusText = "Idle"
        }
    }
}
