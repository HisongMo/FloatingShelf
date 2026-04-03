import SwiftUI
import Cocoa
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @ObservedObject private var fileStorage = FileStorageManager.shared
    @AppStorage("glassBackgroundColor") private var glassBackgroundColor = "black"
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            hotkeysTab
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }

            storageTab
                .tabItem {
                    Label("Storage", systemImage: "archivebox")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 300)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Hotkeys Tab
    
    private var hotkeysTab: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("File Shelf")
                            .font(.system(size: 13, weight: .medium))
                        Text("Hold to show file shelf at cursor")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HotkeyRecorderView(
                        config: $hotkeyManager.fileShelfHotkey,
                        hotkeyManager: hotkeyManager
                    )
                }
                .padding(.vertical, 4)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Launcher")
                            .font(.system(size: 13, weight: .medium))
                        Text("Hold to show app launcher at cursor")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HotkeyRecorderView(
                        config: $hotkeyManager.appLauncherHotkey,
                        hotkeyManager: hotkeyManager
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Storage Tab
    
    private var storageTab: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Stored Files: \(fileStorage.files.count)")
                    .font(.system(size: 13))
                Spacer()
                Button("Clean Missing") {
                    fileStorage.cleanupMissing()
                }
                .font(.system(size: 12))
                
                Button("Clear All") {
                    fileStorage.clearAll()
                }
                .font(.system(size: 12))
                .foregroundColor(.red)
            }
            
            if fileStorage.files.isEmpty {
                Spacer()
                Text("No files stored")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(fileStorage.files) { file in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                                .resizable()
                                .frame(width: 20, height: 20)
                            
                            VStack(alignment: .leading) {
                                Text(file.name)
                                    .font(.system(size: 12))
                                Text(file.path)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if !file.exists {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 11))
                            }
                            
                            Button(role: .destructive) {
                                fileStorage.removeFile(file)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Appearance Tab
    
    private var appearanceTab: some View {
        Form {
            Section {
                Picker("Background Style", selection: $glassBackgroundColor) {
                    Text("Liquid Glass Black").tag("black")
                    Text("Liquid Glass White").tag("white")
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Window Background")
            } footer: {
                Text("Choose the color for both floating windows (File Shelf and App Launcher). Uses the Liquid Glass design language from Xcode 26.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - About Tab
    
    private var aboutTab: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(nsImage: NSImage.customAppIcon)
                .resizable()
                .frame(width: 64, height: 64)
            
            Text("FloatingShelf")
                .font(.system(size: 18, weight: .bold))
            
            Text("v1.0.0")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text("Press and hold a hotkey to summon\na floating space at your cursor.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Hotkey Recorder

struct HotkeyRecorderView: View {
    @Binding var config: HotkeyConfig
    let hotkeyManager: HotkeyManager
    @State private var isRecording = false
    @State private var monitor: Any?
    
    var body: some View {
        Button(action: { toggleRecording() }) {
            Text(isRecording ? "Press a key..." : config.displayString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isRecording ? .orange : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.orange.opacity(0.1) : Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isRecording ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .onDisappear {
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
            isRecording = false
            hotkeyManager.isRecording = false
        }
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        hotkeyManager.isRecording = isRecording
        
        if isRecording {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let masked = event.modifierFlags.rawValue & HotkeyConfig.relevantModifierMask
                if masked != 0 {  // Require at least one modifier
                    config = HotkeyConfig(keyCode: event.keyCode, modifiers: masked)
                }
                isRecording = false
                hotkeyManager.isRecording = false
                if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
                return nil
            }
        } else {
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        }
    }
}
