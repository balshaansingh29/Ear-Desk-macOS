import AppKit
import Carbon

@MainActor
final class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()

    @Published var isANCShortcutEnabled: Bool = UserDefaults.standard.object(forKey: "globalHotkeyEnabled") != nil ? UserDefaults.standard.bool(forKey: "globalHotkeyEnabled") : true {
        didSet {
            UserDefaults.standard.set(isANCShortcutEnabled, forKey: "globalHotkeyEnabled")
            updateRegistration()
        }
    }

    @Published var isGameModeShortcutEnabled: Bool = UserDefaults.standard.object(forKey: "globalHotkeyGameModeEnabled") != nil ? UserDefaults.standard.bool(forKey: "globalHotkeyGameModeEnabled") : false {
        didSet {
            UserDefaults.standard.set(isGameModeShortcutEnabled, forKey: "globalHotkeyGameModeEnabled")
            updateRegistration()
        }
    }

    // Backwards compatibility property
    var isEnabled: Bool {
        get { isANCShortcutEnabled }
        set { isANCShortcutEnabled = newValue }
    }

    private var ancHotKeyRef: EventHotKeyRef?
    private var gameModeHotKeyRef: EventHotKeyRef?
    private var isHandlerInstalled = false
    var onCycleANC: (() -> Void)?
    var onToggleLowLatency: (() -> Void)?

    init() {
        setupHandler()
        updateRegistration()
    }

    private func setupHandler() {
        guard !isHandlerInstalled else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, theEvent, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if status == noErr && hotKeyID.signature == OSType(0x45415244) {
                Task { @MainActor in
                    if hotKeyID.id == 1 {
                        GlobalHotkeyManager.shared.onCycleANC?()
                    } else if hotKeyID.id == 2 {
                        GlobalHotkeyManager.shared.onToggleLowLatency?()
                    }
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
        isHandlerInstalled = true
    }

    func updateRegistration() {
        if let ref = ancHotKeyRef {
            UnregisterEventHotKey(ref)
            ancHotKeyRef = nil
        }
        if let ref = gameModeHotKeyRef {
            UnregisterEventHotKey(ref)
            gameModeHotKeyRef = nil
        }

        // Shortcut 1: Control + Option + A -> Cycle ANC
        if isANCShortcutEnabled {
            let hotKeyID = EventHotKeyID(signature: OSType(0x45415244), id: 1)
            let status = RegisterEventHotKey(
                UInt32(kVK_ANSI_A),
                UInt32(controlKey | optionKey),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ancHotKeyRef
            )
            if status != noErr {
                NSLog("Failed to register ANC global hotkey (status: %d)", status)
            }
        }

        // Shortcut 2: Control + Option + L -> Toggle Low Latency
        if isGameModeShortcutEnabled {
            let hotKeyID = EventHotKeyID(signature: OSType(0x45415244), id: 2)
            let status = RegisterEventHotKey(
                UInt32(kVK_ANSI_L),
                UInt32(controlKey | optionKey),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &gameModeHotKeyRef
            )
            if status != noErr {
                NSLog("Failed to register Low Latency global hotkey (status: %d)", status)
            }
        }
    }
}
