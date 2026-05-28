import Carbon.HIToolbox
import Foundation

final class HotKeyManager {
    private static let hotKeySignature: OSType = 0x434C4854 // 'CLHT'

    private struct RegisteredHotKey {
        let reference: EventHotKeyRef
        let action: ClickShortcutAction
    }

    private var eventHandlerRef: EventHandlerRef?
    private var registeredHotKeys: [UInt32: RegisteredHotKey] = [:]
    private var onTrigger: ((ClickShortcutAction) -> Void)?

    init() {
        installEventHandlerIfNeeded()
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func registerShortcuts(
        _ shortcuts: [ClickShortcutAction: HotKeyBinding],
        onTrigger: @escaping (ClickShortcutAction) -> Void
    ) {
        self.onTrigger = onTrigger
        unregisterAll()

        var seenBindings = Set<HotKeyBinding>()

        for action in ClickShortcutAction.allCases {
            guard let binding = shortcuts[action] else { continue }

            if seenBindings.contains(binding) {
                NSLog("ClickLight: Duplicate shortcut for \(action.rawValue) was ignored.")
                continue
            }

            seenBindings.insert(binding)
            register(action: action, binding: binding)
        }
    }

    func unregisterAll() {
        let refs = registeredHotKeys.values.map(\.reference)
        registeredHotKeys.removeAll()

        for ref in refs {
            UnregisterEventHotKey(ref)
        }
    }

    private func register(action: ClickShortcutAction, binding: HotKeyBinding) {
        guard let eventID = hotKeyEventID(for: action) else { return }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: eventID)

        let status = RegisterEventHotKey(
            UInt32(binding.keyCode),
            UInt32(binding.carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            NSLog("ClickLight: Failed to register shortcut for \(action.rawValue) with status \(status).")
            return
        }

        registeredHotKeys[eventID] = RegisteredHotKey(reference: hotKeyRef, action: action)
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleHotKeyEvent,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
    }

    private func handleHotKey(id: UInt32) {
        guard let action = registeredHotKeys[id]?.action else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?(action)
        }
    }

    private func hotKeyEventID(for action: ClickShortcutAction) -> UInt32? {
        guard let index = ClickShortcutAction.allCases.firstIndex(of: action) else { return nil }
        return UInt32(index + 1)
    }

    private static let handleHotKeyEvent: EventHandlerUPP = { _, eventRef, userData in
        guard let eventRef, let userData else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == HotKeyManager.hotKeySignature else {
            return OSStatus(eventNotHandledErr)
        }

        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        manager.handleHotKey(id: hotKeyID.id)
        return noErr
    }
}
