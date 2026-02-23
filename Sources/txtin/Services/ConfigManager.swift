import Foundation

@MainActor
final class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    private let keychainAccount = "deepgram_api_key"
    private let deepgramPresenceKey = "txtin_has_deepgram_key"
    private let deepgramMaskedPreviewKey = "txtin_deepgram_masked_preview"
    private let transcriptionLanguageKey = "txtin_transcription_language"

    /// Values the user can manually select in the picker.
    private let pickerLanguageCodes: Set<String> = ["auto", "ru", "en"]

    /// Language codes that Deepgram's nova-3 model supports for auto-detection.
    private let deepgramAutoDetectLanguageCodes: Set<String> = [
        "en", "ru", "uk", "es", "fr", "de", "it", "pt", "nl", "pl", "tr", "ja", "ko", "zh", "hi"
    ]
    private var cachedDeepgramKey: String?

    @Published private(set) var hasDeepgramKey = false
    @Published private(set) var transcriptionLanguage = "auto"

    private init() {
        migrateFromUserDefaultsIfNeeded()
        refresh()
    }

    func refresh() {
        // Use exists() (interactionNotAllowed) so startup never triggers a Keychain dialog.
        // The actual value is loaded lazily in deepgramAPIKey() when recording starts.
        if cachedDeepgramKey != nil {
            hasDeepgramKey = true
        } else {
            hasDeepgramKey = KeychainHelper.exists(account: keychainAccount)
        }

        let stored = UserDefaults.standard.string(forKey: transcriptionLanguageKey) ?? "auto"
        transcriptionLanguage = pickerLanguageCodes.contains(stored) ? stored : "auto"
    }

    func setDeepgramAPIKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = KeychainHelper.save(account: keychainAccount, value: trimmed)
        cachedDeepgramKey = trimmed
        hasDeepgramKey = true
        UserDefaults.standard.set(maskedValue(for: trimmed), forKey: deepgramMaskedPreviewKey)
    }

    func deleteDeepgramAPIKey() {
        _ = KeychainHelper.delete(account: keychainAccount)
        cachedDeepgramKey = nil
        hasDeepgramKey = false
        UserDefaults.standard.removeObject(forKey: deepgramPresenceKey)
        UserDefaults.standard.removeObject(forKey: deepgramMaskedPreviewKey)
    }

    func deepgramAPIKey() -> String? {
        if cachedDeepgramKey == nil {
            // Load from Keychain lazily — only when the key is actually needed.
            // This is the one moment the Keychain dialog may appear (user-initiated action).
            cachedDeepgramKey = KeychainHelper.load(account: keychainAccount)
        }
        return cachedDeepgramKey
    }

    func setTranscriptionLanguage(_ value: String) {
        let normalized = pickerLanguageCodes.contains(value) ? value : "auto"
        UserDefaults.standard.set(normalized, forKey: transcriptionLanguageKey)
        refresh()
    }

    func resolvedTranscriptionLanguage() -> String? {
        if transcriptionLanguage == "auto" {
            return detectPreferredLanguageCode()
        }
        return transcriptionLanguage
    }

    func maskedDeepgramKey() -> String? {
        guard let key = cachedDeepgramKey, !key.isEmpty else {
            return UserDefaults.standard.string(forKey: deepgramMaskedPreviewKey)
        }
        return maskedValue(for: key)
    }

    // MARK: - Private

    private func maskedValue(for key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        let middle = String(repeating: "•", count: max(6, key.count - 8))
        return "\(prefix)\(middle)\(suffix)"
    }

    private func detectPreferredLanguageCode() -> String? {
        guard let primary = Locale.preferredLanguages.first else { return nil }
        let code = primary.split(separator: "-").first.map(String.init)?.lowercased()
        guard let code, !code.isEmpty else { return nil }
        guard deepgramAutoDetectLanguageCodes.contains(code) else { return nil }
        return code
    }

    /// One-time migration: moves a key stored in UserDefaults (old format) into Keychain.
    private func migrateFromUserDefaultsIfNeeded() {
        let legacyKey = "txtin_deepgram_api_key_value"
        guard let stored = UserDefaults.standard.string(forKey: legacyKey),
              !stored.isEmpty else { return }
        _ = KeychainHelper.save(account: keychainAccount, value: stored)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }
}
