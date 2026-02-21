import Foundation

@MainActor
final class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    private let deepgramAPIKeyValueKey = "txtin_deepgram_api_key_value"
    private let deepgramPresenceKey = "txtin_has_deepgram_key"
    private let deepgramMaskedPreviewKey = "txtin_deepgram_masked_preview"
    private let transcriptionLanguageKey = "txtin_transcription_language"
    private let supportedAutoLanguageCodes: Set<String> = [
        "en", "ru", "uk", "es", "fr", "de", "it", "pt", "nl", "pl", "tr", "ja", "ko", "zh", "hi"
    ]
    private var cachedDeepgramKey: String?

    @Published private(set) var hasDeepgramKey = false
    @Published private(set) var transcriptionLanguage = "auto"

    private init() {
        refresh()
    }

    func refresh() {
        let storedKey = UserDefaults.standard.string(forKey: deepgramAPIKeyValueKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cachedDeepgramKey = (storedKey?.isEmpty == false) ? storedKey : nil
        hasDeepgramKey = cachedDeepgramKey != nil
        UserDefaults.standard.set(hasDeepgramKey, forKey: deepgramPresenceKey)

        let stored = UserDefaults.standard.string(forKey: transcriptionLanguageKey) ?? "auto"
        transcriptionLanguage = ["auto", "ru", "en"].contains(stored) ? stored : "auto"
    }

    func setDeepgramAPIKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: deepgramAPIKeyValueKey)
        UserDefaults.standard.set(maskedValue(for: trimmed), forKey: deepgramMaskedPreviewKey)
        refresh()
    }

    func deleteDeepgramAPIKey() {
        UserDefaults.standard.removeObject(forKey: deepgramAPIKeyValueKey)
        cachedDeepgramKey = nil
        hasDeepgramKey = false
        UserDefaults.standard.set(false, forKey: deepgramPresenceKey)
        UserDefaults.standard.removeObject(forKey: deepgramMaskedPreviewKey)
        refresh()
    }

    func deepgramAPIKey() -> String? {
        cachedDeepgramKey
    }

    func setTranscriptionLanguage(_ value: String) {
        let normalized = ["auto", "ru", "en"].contains(value) ? value : "auto"
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
        if let key = cachedDeepgramKey, !key.isEmpty {
            return maskedValue(for: key)
        }
        return UserDefaults.standard.string(forKey: deepgramMaskedPreviewKey)
    }

    private func maskedValue(for key: String) -> String {
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(min(4, key.count)))
        return "\(prefix)\(String(repeating: "•", count: max(6, key.count - 8)))\(suffix)"
    }

    private func detectPreferredLanguageCode() -> String? {
        guard let primary = Locale.preferredLanguages.first else { return nil }
        let code = primary.split(separator: "-").first.map(String.init)?.lowercased()
        guard let code, !code.isEmpty else { return nil }
        guard supportedAutoLanguageCodes.contains(code) else { return nil }
        return code
    }
}
