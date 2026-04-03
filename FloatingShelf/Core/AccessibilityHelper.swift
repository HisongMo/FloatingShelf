import Cocoa

enum AccessibilityHelper {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }
    
    static func requestAccessibilityPermissions() {
        // This triggers the system prompt to trust the current process
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            DispatchQueue.main.async {
                let bundlePath = Bundle.main.bundlePath
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = """
                FloatingShelf 需要「辅助功能」权限才能检测全局快捷键。
                
                请按以下步骤操作：
                1. 点击下方「打开系统设置」按钮
                2. 如果列表中已有 FloatingShelf，先将其移除（选中后点 "-"）
                3. 点击「+」按钮，导航到以下路径添加应用：
                
                \(bundlePath)
                
                4. 确保开关已打开
                5. 权限生效后无需重启应用
                """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "复制应用路径")
                alert.addButton(withTitle: "稍后")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                } else if response == .alertSecondButtonReturn {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bundlePath, forType: .string)
                    
                    let copied = NSAlert()
                    copied.messageText = "路径已复制"
                    copied.informativeText = "应用路径已复制到剪贴板。\n请在辅助功能设置中通过「+」按钮添加此应用。\n\n提示：在 Finder 的「前往」菜单中选择「前往文件夹...」，粘贴路径即可快速定位。"
                    copied.runModal()
                    
                    let sysUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(sysUrl)
                }
            }
        }
    }
}
