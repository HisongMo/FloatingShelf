import Cocoa

class FloatingPanel: NSPanel {
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: true
        )
        
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isMovableByWindowBackground = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.animationBehavior = .utilityWindow
        self.isReleasedWhenClosed = false
        self.isRestorable = false
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    func show() {
        let mouseLocation = NSEvent.mouseLocation
        let size = self.frame.size
        
        var x = mouseLocation.x - size.width / 2
        var y = mouseLocation.y - size.height / 2
        
        // Keep within screen bounds
        if let screen = screenForMouseLocation() {
            let vis = screen.visibleFrame
            x = max(vis.minX + 8, min(x, vis.maxX - size.width - 8))
            y = max(vis.minY + 8, min(y, vis.maxY - size.height - 8))
        }
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
        self.alphaValue = 0
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }
    
    func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1  // Reset for next show
        })
    }
    
    private func screenForMouseLocation() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
