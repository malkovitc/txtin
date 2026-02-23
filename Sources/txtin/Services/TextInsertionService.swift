import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum TextInsertionResult {
    case inserted
    case copiedToClipboard(String)
    case failed(String)
}

@MainActor
final class TextInsertionService {
    static let shared = TextInsertionService()

    private init() {}

    func insertText(_ text: String) async -> TextInsertionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failed("No speech detected")
        }

        let trusted = AXIsProcessTrusted()
        if !trusted {
            requestAccessibilityPrompt()
            copyToClipboard(trimmed)
            return .copiedToClipboard("Accessibility permission is required for text insertion. Transcript copied to clipboard.")
        }

        let snapshot = capturePasteboard()
        copyToClipboard(trimmed)
        let expectedChangeCount = NSPasteboard.general.changeCount

        try? await Task.sleep(nanoseconds: 120_000_000)
        guard simulatePasteShortcut() else {
            // Keep transcript in clipboard as a safe fallback if paste simulation fails.
            return .copiedToClipboard("Could not paste automatically. Transcript copied to clipboard.")
        }

        try? await Task.sleep(nanoseconds: 200_000_000)
        restorePasteboardIfUnchanged(snapshot, expectedChangeCount: expectedChangeCount)
        return .inserted
    }

    private func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private typealias PasteboardSnapshot = [[NSPasteboard.PasteboardType: Data]]

    private func capturePasteboard() -> PasteboardSnapshot {
        let pasteboard = NSPasteboard.general
        guard let items = pasteboard.pasteboardItems else { return [] }

        return items.map { item in
            var payload: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    payload[type] = data
                }
            }
            return payload
        }
    }

    private func restorePasteboardIfUnchanged(_ snapshot: PasteboardSnapshot, expectedChangeCount: Int) {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == expectedChangeCount else { return }
        guard !snapshot.isEmpty else { return }

        pasteboard.clearContents()

        let items: [NSPasteboardItem] = snapshot.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(items)
    }

    private func simulatePasteShortcut() -> Bool {
        let vKey = CGKeyCode(kVK_ANSI_V)
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)

        keyUp.flags = .maskCommand
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
