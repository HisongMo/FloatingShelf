import Cocoa
import Combine
import Carbon

// MARK: - Hotkey Configuration

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt  // NSEvent.ModifierFlags.rawValue, masked to relevant bits
    
    static let relevantModifierMask: UInt =
        NSEvent.ModifierFlags([.option, .command, .control, .shift]).rawValue
    
    // Default: ⌥+D for file shelf, ⌥+A for app launcher
    static let defaultFileShelf = HotkeyConfig(keyCode: 2, modifiers: NSEvent.ModifierFlags.option.rawValue)
    static let defaultAppLauncher = HotkeyConfig(keyCode: 0, modifiers: NSEvent.ModifierFlags.option.rawValue)
    
    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }
    
    static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
            22: "6", 26: "7", 28: "8", 25: "9", 29: "0", 24: "=", 27: "-",
            30: "]", 33: "[", 39: "'", 42: "\\", 43: ",", 47: ".", 44: "/",
            41: ";", 50: "`", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
            97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return names[keyCode] ?? "Key(\(keyCode))"
    }
}

// MARK: - Hotkey Manager

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    @Published var fileShelfHotkey: HotkeyConfig { didSet { saveConfig(); startMonitoring() } }
    @Published var appLauncherHotkey: HotkeyConfig { didSet { saveConfig(); startMonitoring() } }
    @Published var isMonitoring = false
    @Published var debugLog: String = ""
    
    var onFileShelfKeyDown: (() -> Void)?
    var onFileShelfKeyUp: (() -> Void)?
    var onAppLauncherKeyDown: (() -> Void)?
    var onAppLauncherKeyUp: (() -> Void)?
    
    // Carbon references
    fileprivate var fileShelfHotKeyRef: EventHotKeyRef?
    fileprivate var appLauncherHotKeyRef: EventHotKeyRef?
    fileprivate var eventHandlerRef: EventHandlerRef?
    
    private(set) var fileShelfActive = false
    private(set) var appLauncherActive = false
    
    var isRecording = false {
        didSet {
            if isRecording {
                stopMonitoring()  // Temporarily stop global hotkeys when recording
            } else {
                startMonitoring()
            }
        }
    }
    
    private init() {
        if let d = UserDefaults.standard.data(forKey: "fsHotkey"),
           let c = try? JSONDecoder().decode(HotkeyConfig.self, from: d) {
            fileShelfHotkey = c
        } else {
            UserDefaults.standard.removeObject(forKey: "fsHotkey")
            fileShelfHotkey = .defaultFileShelf
        }
        if let d = UserDefaults.standard.data(forKey: "alHotkey"),
           let c = try? JSONDecoder().decode(HotkeyConfig.self, from: d) {
            appLauncherHotkey = c
        } else {
            UserDefaults.standard.removeObject(forKey: "alHotkey")
            appLauncherHotkey = .defaultAppLauncher
        }
    }
    
    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(ts)] \(msg)"
        NSLog("FloatingShelf: %@", msg)
        DispatchQueue.main.async {
            self.debugLog += line + "\n"
            // Keep last 50 lines
            let lines = self.debugLog.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.count > 50 {
                self.debugLog = lines.suffix(50).joined(separator: "\n")
            }
        }
    }
    
    private func saveConfig() {
        if let d = try? JSONEncoder().encode(fileShelfHotkey) {
            UserDefaults.standard.set(d, forKey: "fsHotkey")
        }
        if let d = try? JSONEncoder().encode(appLauncherHotkey) {
            UserDefaults.standard.set(d, forKey: "alHotkey")
        }
    }
    
    // MARK: - Start / Stop (Carbon APIs)
    
    func startMonitoring() {
        stopMonitoring()
        
        guard !isRecording else { return }
        
        // 1. Install Global Event Handler
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonEventHandler,
            2,
            &eventTypes,
            selfPtr,
            &eventHandlerRef
        )
        
        guard status == noErr else {
            log("❌ Carbon global hotkey registration failed with status: \(status)")
            return
        }
        
        // 2. Register Hotkeys
        registerHotkeys()
        
        isMonitoring = true
        log("✅ Global monitoring ACTIVE (using Carbon APIs, no Accessibility required)")
    }
    
    private func registerHotkeys() {
        let fsMacMods = getCarbonFlags(from: fileShelfHotkey.modifiers)
        var fsID = EventHotKeyID(signature: 0x4653484C, id: 1) // "FSHL"
        RegisterEventHotKey(UInt32(fileShelfHotkey.keyCode), fsMacMods, fsID, GetApplicationEventTarget(), 0, &fileShelfHotKeyRef)
        
        let alMacMods = getCarbonFlags(from: appLauncherHotkey.modifiers)
        var alID = EventHotKeyID(signature: 0x4150504C, id: 2) // "APPL"
        RegisterEventHotKey(UInt32(appLauncherHotkey.keyCode), alMacMods, alID, GetApplicationEventTarget(), 0, &appLauncherHotKeyRef)
    }

    private func getCarbonFlags(from nsModifiers: UInt) -> UInt32 {
        var carbonFlags: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: nsModifiers)
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbonFlags |= UInt32(shiftKey) }
        return carbonFlags
    }
    
    func stopMonitoring() {
        if let ref = fileShelfHotKeyRef { UnregisterEventHotKey(ref); fileShelfHotKeyRef = nil }
        if let ref = appLauncherHotKeyRef { UnregisterEventHotKey(ref); appLauncherHotKeyRef = nil }
        if let handler = eventHandlerRef { RemoveEventHandler(handler); eventHandlerRef = nil }
        isMonitoring = false
        fileShelfActive = false
        appLauncherActive = false
    }

    func handleHotKeyDown(id: UInt32) {
        log("🟢 Global KeyDown for ID: \(id)")
        if id == 1 && !fileShelfActive {
            fileShelfActive = true
            onFileShelfKeyDown?()
        } else if id == 2 && !appLauncherActive {
            appLauncherActive = true
            onAppLauncherKeyDown?()
        }
    }
    
    func handleHotKeyUp(id: UInt32) {
        log("🔴 Global KeyUp for ID: \(id)")
        if id == 1 && fileShelfActive {
            fileShelfActive = false
            onFileShelfKeyUp?()
        } else if id == 2 && appLauncherActive {
            appLauncherActive = false
            onAppLauncherKeyUp?()
        }
    }
    
    // MARK: - Debug Test
    
    func testGlobalMonitor(completion: @escaping (String) -> Void) {
        completion("Using Carbon APIs — hotkeys are natively global and require no permissions. Just test the defined hotkeys!")
    }
}

// MARK: - C Callback

private func carbonEventHandler(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = theEvent, let userData = userData else { return OSStatus(eventNotHandledErr) }
    
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    let kind = GetEventKind(event)
    
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
    
    if status != noErr { return OSStatus(eventNotHandledErr) }
    
    if kind == kEventHotKeyPressed {
        manager.handleHotKeyDown(id: hotKeyID.id)
        return OSStatus(noErr)
    } else if kind == kEventHotKeyReleased {
        manager.handleHotKeyUp(id: hotKeyID.id)
        return OSStatus(noErr)
    }
    
    return OSStatus(eventNotHandledErr)
}
