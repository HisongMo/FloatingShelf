import Foundation
import AppKit
import Combine

class AppEnumerator: ObservableObject {
    static let shared = AppEnumerator()
    
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var hoveredAppId: String?
    @Published var isSearching = false
    
    /// Simply returns apps in alphabetical order — no recency sorting
    var sortedApps: [InstalledApp] { apps }
    
    private init() {}
    
    func loadApps() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = Self.enumerateApps()
            DispatchQueue.main.async {
                self?.apps = found
                self?.isLoading = false
            }
        }
    }
    
    func recordClick(appId: String) {
        // No-op: recency tracking removed
    }
    
    /// Only scan /Applications (and its one-level subdirectories)
    private static func enumerateApps() -> [InstalledApp] {
        let fm = FileManager.default
        var appURLs: [URL] = []
        
        // Finder's "Applications" merges both directories
        let scanDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications")
        ]
        
        for appDir in scanDirs {
            // Scan top level
            if let enumerator = fm.enumerator(
                at: appDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "app" {
                        appURLs.append(fileURL)
                    }
                }
            }
        }
        
        // Scan one-level subdirectories (e.g. /Applications/Utilities, /System/Applications/Utilities)
        for appDir in scanDirs {
            if let items = try? fm.contentsOfDirectory(at: appDir, includingPropertiesForKeys: [.isDirectoryKey]) {
                for item in items {
                    if item.hasDirectoryPath && item.pathExtension != "app" {
                        if let subEnum = fm.enumerator(
                            at: item,
                            includingPropertiesForKeys: [.isDirectoryKey],
                            options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
                        ) {
                            for case let subURL as URL in subEnum {
                                if subURL.pathExtension == "app" {
                                    appURLs.append(subURL)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Build models, deduplicate by path
        var seen = Set<String>()
        var results: [InstalledApp] = []
        
        for url in appURLs {
            let path = url.path
            guard !seen.contains(path) else { continue }
            seen.insert(path)
            
            let bundle = Bundle(url: url)
            let name = Self.localizedAppName(for: url, bundle: bundle, fm: fm)
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
    
    /// Get the localized display name for an app
    private static func localizedAppName(for url: URL, bundle: Bundle?, fm: FileManager) -> String {
        let fallback = url.deletingPathExtension().lastPathComponent
        guard let bundle = bundle else { return fallback }
        
        let resourcesPath = bundle.resourcePath ?? (bundle.bundlePath + "/Contents/Resources")
        
        // Build locale candidates: both dash (zh-Hans) and underscore (zh_CN) variants
        // "zh-Hans-CN" -> ["zh-Hans-CN", "zh_Hans_CN", "zh-Hans", "zh_Hans", "zh_CN", "zh"]
        var candidates: [String] = []
        for lang in Locale.preferredLanguages {
            candidates.append(lang)
            candidates.append(lang.replacingOccurrences(of: "-", with: "_"))
            let parts = lang.components(separatedBy: "-")
            if parts.count >= 3 {
                // zh-Hans-CN -> zh-Hans, zh_Hans, zh_CN
                let sub = parts[0..<2].joined(separator: "-")
                candidates.append(sub)
                candidates.append(sub.replacingOccurrences(of: "-", with: "_"))
                candidates.append(parts[0] + "_" + parts[2])  // zh_CN
            }
            if parts.count >= 2 {
                candidates.append(parts[0])
            }
        }
        candidates.append("Base")
        
        // 1. Try .loctable file (macOS 26 system apps use this)
        let loctablePath = resourcesPath + "/InfoPlist.loctable"
        if fm.fileExists(atPath: loctablePath),
           let data = fm.contents(atPath: loctablePath),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            for candidate in candidates {
                if let locDict = plist[candidate] as? [String: String] {
                    if let dn = locDict["CFBundleDisplayName"], !dn.isEmpty { return dn }
                    if let bn = locDict["CFBundleName"], !bn.isEmpty { return bn }
                }
            }
        }
        
        // 2. Try .lproj/InfoPlist.strings (traditional format)
        for candidate in candidates {
            let stringsPath = resourcesPath + "/" + candidate + ".lproj/InfoPlist.strings"
            if fm.fileExists(atPath: stringsPath),
               let dict = NSDictionary(contentsOfFile: stringsPath) {
                if let dn = dict["CFBundleDisplayName"] as? String, !dn.isEmpty { return dn }
                if let bn = dict["CFBundleName"] as? String, !bn.isEmpty { return bn }
            }
        }
        
        // 3. Fallback: bundle API
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? fallback
    }
}
