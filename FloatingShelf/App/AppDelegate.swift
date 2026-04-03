import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var fileShelfPanel: FloatingPanel!
    private var appLauncherPanel: FloatingPanel!
    
    private let hotkeyManager = HotkeyManager.shared
    private let fileStorage = FileStorageManager.shared
    private let appEnumerator = AppEnumerator.shared
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        // Disable window state restoration globally BEFORE any windows are created
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        // Clean up old autosave frames that could trigger restoration
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame fs_panel")
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame al_panel")
    }
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("FloatingShelf: applicationDidFinishLaunching START")
        
        // Aggressively close any existing windows (restored by macOS)
        for window in NSApp.windows {
            if window is NSPanel {
                window.orderOut(nil)
                window.close()
            }
        }
        
        // Create panels
        createFileShelfPanel()
        createAppLauncherPanel()
        NSLog("FloatingShelf: Panels created")
        
        // Setup hotkey callbacks
        setupHotkeyCallbacks()
        NSLog("FloatingShelf: Callbacks registered")
        
        // Start monitoring
        hotkeyManager.startMonitoring()
        NSLog("FloatingShelf: startMonitoring called, isMonitoring=\(hotkeyManager.isMonitoring)")
        
        // Pre-load apps
        appEnumerator.loadApps()
        NSLog("FloatingShelf: applicationDidFinishLaunching DONE")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stopMonitoring()
    }
    
    // MARK: - Panels
    
    private func createFileShelfPanel() {
        let view = FileShelfView()
            .environmentObject(fileStorage)
        
        fileShelfPanel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 320))
        fileShelfPanel.contentView = NSHostingView(rootView: view)
        fileShelfPanel.minSize = NSSize(width: 120, height: 120)
        
        fileStorage.$files
            .receive(on: DispatchQueue.main)
            .sink { [weak self] files in
                self?.updateFileShelfSize(count: files.count)
            }
            .store(in: &cancellables)
    }
    
    private func updateFileShelfSize(count: Int) {
        if count == 0 {
            let size = NSSize(width: 250, height: 250)
            applyCenteredFrame(size: size)
            return
        }
        
        let columns = count == 1 ? 1 : Swift.min(max(Int(ceil(sqrt(Double(count)))), 2), 5)
        let rows = Int(ceil(Double(count) / Double(columns)))
        
        // itemW = adaptive(min 72, max 80), colSpacing = 12, hPad = 16*2 = 32
        // itemH = tileSize(64) + vSpacing(6) + labelH(~22) = 92, rowSpacing = 12, vPad = 16*2 = 32
        let width  = CGFloat(columns) * 80.0 + CGFloat(columns - 1) * 12.0 + 32.0
        let height = CGFloat(rows)    * 92.0 + CGFloat(rows    - 1) * 12.0 + 32.0
        
        let newSize = NSSize(width: max(120, width), height: max(120, height))
        applyCenteredFrame(size: newSize)
    }
    
    private func applyCenteredFrame(size: NSSize) {
        var frame = fileShelfPanel.frame
        let oldCenter = NSPoint(x: frame.midX, y: frame.midY)
        frame.size = size
        frame.origin = NSPoint(x: oldCenter.x - size.width / 2, y: oldCenter.y - size.height / 2)
        
        fileShelfPanel.setFrame(frame, display: true, animate: true)
    }
    
    private func createAppLauncherPanel() {
        let view = AppGridView()
            .environmentObject(appEnumerator)
        
        // Panel size: 7 cols × 3 rows + search bar + dots
        // panelW = 7*72 + 6*14 + 20*2 = 504 + 84 + 40 = 628
        // panelH = 40(search) + (3*98 + 2*12 + 16*2)(grid=350) + 22(dots) = 412
        let panelW: CGFloat = 628
        let panelH: CGFloat = 412
        
        appLauncherPanel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: panelW, height: panelH))
        appLauncherPanel.contentView = NSHostingView(rootView: view)
        appLauncherPanel.minSize = NSSize(width: panelW, height: panelH)
        appLauncherPanel.maxSize = NSSize(width: panelW, height: panelH)
    }
    
    // MARK: - Hotkey Callbacks
    
    private func setupHotkeyCallbacks() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HideFileShelf"), object: nil, queue: .main) { [weak self] _ in
            self?.fileShelfPanel.hide()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HideAppLauncher"), object: nil, queue: .main) { [weak self] _ in
            self?.appEnumerator.isSearching = false
            self?.appLauncherPanel.hide()
        }
        
        hotkeyManager.onFileShelfKeyDown = { [weak self] in
            self?.appLauncherPanel.orderOut(nil)
            self?.appLauncherPanel.alphaValue = 1
            self?.fileShelfPanel.show()
        }
        
        hotkeyManager.onFileShelfKeyUp = { [weak self] in
            if self?.fileStorage.isEditingNote == true { return }
            
            if let hoveredId = self?.fileStorage.hoveredFileId,
               let file = self?.fileStorage.files.first(where: { $0.id == hoveredId }),
               file.exists {
                self?.fileStorage.hoveredFileId = nil
                NSWorkspace.shared.open(file.url)
            }
            self?.fileShelfPanel.hide()
        }
        
        hotkeyManager.onAppLauncherKeyDown = { [weak self] in
            self?.fileShelfPanel.orderOut(nil)
            self?.fileShelfPanel.alphaValue = 1
            self?.appLauncherPanel.show()
        }
        
        hotkeyManager.onAppLauncherKeyUp = { [weak self] in
            // If the user is searching, don't hide the panel
            if self?.appEnumerator.isSearching == true { return }
            
            if let hoveredId = self?.appEnumerator.hoveredAppId,
               let app = self?.appEnumerator.apps.first(where: { $0.id == hoveredId }) {
                self?.appEnumerator.hoveredAppId = nil
                self?.appEnumerator.recordClick(appId: hoveredId)
                NSWorkspace.shared.open(app.url)
            }
            self?.appLauncherPanel.hide()
        }
    }
}
