import Carbon.HIToolbox
import ClipboardCore
import Foundation

/// The shortcuts the app claims globally.
public enum HotkeySlot: String, CaseIterable, Sendable {
    case openHistory
    case pastePlainText
}

public enum HotkeyError: Error, Equatable, LocalizedError {
    /// The combo has no Command, Control or Option modifier and would swallow
    /// ordinary typing.
    case invalidCombo
    case registrationFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidCombo:
            return "A shortcut needs at least one of Command, Control or Option."
        case .registrationFailed(let status):
            if status == OSStatus(eventHotKeyExistsErr) {
                return "That shortcut is already used by another app."
            }
            return "That shortcut could not be registered (error \(status)). Try another one."
        }
    }
}

/// Registers global shortcuts through Carbon's `RegisterEventHotKey`.
///
/// Carbon hotkeys are the only mechanism that delivers a system-wide shortcut
/// without Accessibility permission, which matters because the app must be able
/// to open its history on a clean install before the user has granted anything.
@MainActor
public final class GlobalHotkeyManager {
    /// Four-char code 'CBDX', distinguishing our hotkeys from other apps' in
    /// Carbon's global registry.
    private static let signature = OSType(0x4342_4458)

    public private(set) var registeredCombos: [HotkeySlot: KeyCombo] = [:]

    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    /// Kept apart from `handlers` so `deinit` can release the Carbon resources
    /// without reaching for main-actor state.
    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    public init() {}

    deinit {
        for reference in hotKeys.values {
            UnregisterEventHotKey(reference)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    // MARK: - Registration

    /// Claims `combo` for `slot`, replacing whatever that slot held before.
    ///
    /// An unusable combo is rejected before anything is torn down, so a bad entry
    /// in the shortcut recorder leaves the working shortcut alone. A combo the
    /// system refuses does empty the slot, so the app never keeps responding to a
    /// shortcut the user believes they replaced.
    @discardableResult
    public func register(
        _ combo: KeyCombo, for slot: HotkeySlot, handler: @escaping @MainActor () -> Void
    ) -> Result<Void, HotkeyError> {
        guard combo.isValid else { return .failure(.invalidCombo) }
        unregister(slot)

        let installStatus = installEventHandlerIfNeeded()
        guard installStatus == noErr else { return .failure(.registrationFailed(installStatus)) }

        let identifier = Self.identifier(for: slot)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            combo.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: identifier),
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            return .failure(.registrationFailed(status == noErr ? OSStatus(eventInternalErr) : status))
        }

        hotKeys[identifier] = reference
        handlers[identifier] = handler
        registeredCombos[slot] = combo
        return .success(())
    }

    public func unregister(_ slot: HotkeySlot) {
        let identifier = Self.identifier(for: slot)
        if let reference = hotKeys.removeValue(forKey: identifier) {
            UnregisterEventHotKey(reference)
        }
        handlers.removeValue(forKey: identifier)
        registeredCombos.removeValue(forKey: slot)
    }

    public func unregisterAll() {
        for slot in HotkeySlot.allCases {
            unregister(slot)
        }
    }

    // MARK: - Dispatch

    private func installEventHandlerIfNeeded() -> OSStatus {
        guard eventHandler == nil else { return noErr }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)
        )
        var reference: EventHandlerRef?
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotkeyEventHandler,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &reference
        )
        if status == noErr {
            eventHandler = reference
        }
        return status
    }

    fileprivate func dispatch(identifier: UInt32) {
        handlers[identifier]?()
    }

    // MARK: - Slot identifiers

    private static func identifier(for slot: HotkeySlot) -> UInt32 {
        switch slot {
        case .openHistory: return 1
        case .pastePlainText: return 2
        }
    }
}

/// Carbon delivers hotkeys on the main run loop, so the handler hops straight
/// onto the main actor instead of scheduling another turn: the panel must appear
/// in the same event cycle the shortcut was pressed in.
private func hotkeyEventHandler(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    let identifier = hotKeyID.id
    MainActor.assumeIsolated {
        manager.dispatch(identifier: identifier)
    }
    return noErr
}
