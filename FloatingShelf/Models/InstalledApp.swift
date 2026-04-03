import Foundation
import AppKit

struct InstalledApp: Identifiable, Hashable {
    let id: String // bundle path
    let name: String
    let bundlePath: String
    let bundleIdentifier: String?
    
    var url: URL { URL(fileURLWithPath: bundlePath) }
    
    var icon: NSImage {
        let icon = NSWorkspace.shared.icon(forFile: bundlePath)
        icon.size = NSSize(width: 128, height: 128)
        icon.isTemplate = false
        return icon
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}
