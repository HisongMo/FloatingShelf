import Foundation
import AppKit
import Combine

class AppEnumerator: ObservableObject {
    static let shared = AppEnumerator()
    
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var hoveredAppId: String?
    
    // Store recent history (app IDs, mostly paths)
    @Published var recentAppIds: [String] = []
    
    var sortedApps: [InstalledApp] {
        // Create an index dictionary for fast lookup of recency
        var recencyMap = [String: Int]()
        for (index, id) in recentAppIds.enumerated() {
            recencyMap[id] = index
        }
        
        return apps.sorted { app1, app2 in
            let r1 = recencyMap[app1.id]
            let r2 = recencyMap[app2.id]
            
            if let r1 = r1, let r2 = r2 {
                return r1 < r2 // Both recent, compare recency order
            } else if r1 != nil {
                return true    // app1 is recent, app2 is not
            } else if r2 != nil {
                return false   // app2 is recent, app1 is not
            } else {
                // Neither is recent, preserve alphabetical sorting which is how 'apps' is loaded
                return false // Using stable sort assumes `apps` is already alphabetized
            }
        }
    }
    
    private init() {
        if let stored = UserDefaults.standard.array(forKey: "recentAppIds") as? [String] {
            recentAppIds = stored
        }
    }
    
    func loadApps() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = Self.enumerateApps()
            // Found is already alphabetically sorted by enumerateApps()
            DispatchQueue.main.async {
                self?.apps = found
                self?.isLoading = false
            }
        }
    }
    
    func recordClick(appId: String) {
        // Remove if it's already in the list
        if let i = recentAppIds.firstIndex(of: appId) {
            recentAppIds.remove(at: i)
        }
        // Insert at the front (index 0 is most recent)
        recentAppIds.insert(appId, at: 0)
        
        // Limit to 40 recent apps
        if recentAppIds.count > 40 {
            recentAppIds = Array(recentAppIds.prefix(40))
        }
        
        // Save
        UserDefaults.standard.set(recentAppIds, forKey: "recentAppIds")
    }
    
    private static func enumerateApps() -> [InstalledApp] {
        let fm = FileManager.default
        var appURLs: [URL] = []
        
        let roots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
        ]
        
        for root in roots where fm.fileExists(atPath: root.path) {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            for case let url as URL in enumerator {
                if (try? url.resourceValues(forKeys: [.isApplicationKey]).isApplication) == true
                    || url.pathExtension.lowercased() == "app" {
                    appURLs.append(url)
                }
            }
        }
        
        // Remove duplicates and build models
        var seen = Set<String>()
        var results: [InstalledApp] = []
        
        for url in appURLs {
            let path = url.path
            guard !seen.contains(path) else { continue }
            seen.insert(path)
            
            let bundle = Bundle(url: url)
            let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                     ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                     ?? url.deletingPathExtension().lastPathComponent
            let bundleId = bundle?.bundleIdentifier
            
            results.append(InstalledApp(
                id: path,
                name: name,
                bundlePath: path,
                bundleIdentifier: bundleId
            ))
        }
        
        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
