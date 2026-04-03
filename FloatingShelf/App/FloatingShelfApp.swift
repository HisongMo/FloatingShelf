import SwiftUI

extension NSImage {
    static var customAppIcon: NSImage {
        if let iconFile = Bundle.main.infoDictionary?["CFBundleIconFile"] as? String {
            if let url = Bundle.main.url(forResource: iconFile, withExtension: "icns"), let image = NSImage(contentsOf: url) {
                return image
            }
            if let url = Bundle.main.url(forResource: iconFile, withExtension: nil), let image = NSImage(contentsOf: url) {
                return image
            }
        }
        if let image = NSImage(named: "thisIcon") {
            return image
        }
        return NSApplication.shared.applicationIconImage
    }
}

@main
struct FloatingShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    
    var body: some Scene {
        MenuBarExtra {
            Label("File Shelf  (\(hotkeyManager.fileShelfHotkey.displayString))", systemImage: "archivebox")
            Label("App Launcher  (\(hotkeyManager.appLauncherHotkey.displayString))", systemImage: "square.grid.2x2")
            
            Divider()
            
            if hotkeyManager.isMonitoring {
                Label("Monitoring: Active ✅", systemImage: "checkmark.circle")
            } else {
                Label("Monitoring: Inactive ❌", systemImage: "xmark.circle")
            }
            
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit FloatingShelf") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(nsImage: {
                let img = NSImage.customAppIcon.copy() as! NSImage
                img.size = NSSize(width: 18, height: 18)
                return img
            }())
        }
        
        Settings {
            SettingsView()
        }
    }
}
