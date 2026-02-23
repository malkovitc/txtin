import Foundation
import Carbon

private func hotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    let eventKind = GetEventKind(event)
    let isPressed = eventKind == UInt32(kEventHotKeyPressed)
    let isReleased = eventKind == UInt32(kEventHotKeyReleased)
    guard isPressed || isReleased else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        UInt32(kEventParamDirectObject),
        UInt32(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr else {
        return OSStatus(eventNotHandledErr)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    if hotKeyID.id == 1 {
        DispatchQueue.main.async {
            if isPressed {
                manager.onPressed?()
            } else if isReleased {
                manager.onReleased?()
            }
        }
        return noErr
    }

    return OSStatus(eventNotHandledErr)
}

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private static let signature: OSType = 0x5458544E // 'TXTN'

    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?
    private(set) var lastRegistrationError: String?
    private(set) var isHotkeyRegistered = false

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    private init() {
        installHandler()
    }

    @discardableResult
    func registerOptionQ() -> Bool {
        unregisterHotkey()

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_Q),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            let message = "Failed to register Option+Q (status: \(status))"
            lastRegistrationError = message
            isHotkeyRegistered = false
            NSLog("[Hotkey] \(message)")
            return false
        }

        lastRegistrationError = nil
        isHotkeyRegistered = true
        return true
    }

    private func installHandler() {
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            2,
            &eventTypes,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        if status != noErr {
            let message = "Failed to install hotkey handler (status: \(status))"
            lastRegistrationError = message
            NSLog("[Hotkey] \(message)")
        }
    }

    private func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            isHotkeyRegistered = false
        }
    }
}
