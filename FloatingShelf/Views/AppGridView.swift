import SwiftUI
import AppKit

// MARK: - Layout Constants
private enum Grid {
    static let cols        = 7
    static let rows        = 3
    static let tileSize:   CGFloat = 72    // glass tile & icon container
    static let iconSize:   CGFloat = 56    // app icon image inside tile
    static let labelH:     CGFloat = 20
    static let itemH:      CGFloat = tileSize + 6 + labelH   // 98
    static let colSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 12
    static let hPad:       CGFloat = 20
    static let vPad:       CGFloat = 16
    static let dotsH:      CGFloat = 22

    // Golden ratio horizontal: w ≈ h × 1.618
    static let panelW: CGFloat = CGFloat(cols) * tileSize + CGFloat(cols - 1) * colSpacing + hPad * 2
    static let gridH:  CGFloat = CGFloat(rows) * itemH + CGFloat(rows - 1) * rowSpacing + vPad * 2
    static let panelH: CGFloat = gridH + dotsH
}

// MARK: - Scroll State (shared across view updates)

private class ScrollState {
    var isGestureActive = false
    var gestureHandled = false
    var scrollAccumX: CGFloat = 0
    var scrollAccumY: CGFloat = 0
    var mouseWheelLocked = false
}

struct AppGridView: View {
    @EnvironmentObject var appEnumerator: AppEnumerator
    @State private var currentPage  = 0
    @State private var dragOffset:  CGFloat = 0
    @State private var focusedIndex: Int?   = nil
    @State private var scrollMonitor: Any?  = nil
    @State private var keyMonitor: Any?     = nil

    private let perPage = Grid.cols * Grid.rows
    private let scrollState = ScrollState()

    var body: some View {
        ZStack {
            // Solid white background for contrast debugging
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)

            if appEnumerator.isLoading {
                loadingState
            } else if appEnumerator.sortedApps.isEmpty {
                emptyState
            } else {
                appGrid
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(width: Grid.panelW, height: Grid.panelH)
        .environment(\.controlActiveState, .active)
        .onAppear { installEventMonitors() }
        .onDisappear { removeEventMonitors() }
    }

    // MARK: - Event Monitors (no overlay, no mouse blocking)
    
    private func installEventMonitors() {
        // Scroll wheel monitor
        if scrollMonitor == nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
                self.handleScrollEvent(event)
                return event
            }
        }
        // Keyboard monitor
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                let arrows: [UInt16] = [123, 124, 125, 126, 36, 76]
                if arrows.contains(event.keyCode) {
                    self.handleKey(event.keyCode)
                    return nil // consume the event
                }
                return event
            }
        }
    }
    
    private func removeEventMonitors() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    // MARK: - App Grid (Launchpad-style paging)

    private var appGrid: some View {
        let apps      = appEnumerator.sortedApps
        let pages = stride(from: 0, to: apps.count, by: perPage).map { start in
            Array(apps[start..<min(start + perPage, apps.count)])
        }
        let pageCount = max(1, pages.count)
        let cp        = min(currentPage, pageCount - 1)
        let gridCols  = Array(repeating: GridItem(.fixed(Grid.tileSize), spacing: Grid.colSpacing), count: Grid.cols)
        
        // Launchpad-style transition: current page shrinks + fades, next page grows + fades in
        let dragRatio = abs(dragOffset) / Grid.panelW
        let exitScale: CGFloat = max(0.85, 1.0 - dragRatio * 0.15)
        let exitOpacity: Double = max(0.3, 1.0 - Double(dragRatio) * 0.7)
        let enterScale: CGFloat = min(1.0, 0.85 + dragRatio * 0.15)
        let enterOpacity: Double = min(1.0, 0.3 + Double(dragRatio) * 0.7)

        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { page, pageApps in

                        LazyVGrid(columns: gridCols, spacing: Grid.rowSpacing) {
                            ForEach(Array(pageApps.enumerated()), id: \.element.id) { localIdx, app in
                                let globalIdx = page * perPage + localIdx
                                let isFocused = focusedIndex == globalIdx
                                AppItemView(
                                    app: app,
                                    isHovered: appEnumerator.hoveredAppId == app.id || isFocused
                                )
                                .onHover { h in appEnumerator.hoveredAppId = h ? app.id : nil }
                                .onTapGesture {
                                    appEnumerator.recordClick(appId: app.id)
                                    NSWorkspace.shared.open(app.url)
                                }
                            }
                        }
                        .padding(.horizontal, Grid.hPad)
                        .padding(.vertical, Grid.vPad)
                        .frame(width: Grid.panelW, alignment: .topLeading)
                        // Keep full brightness at rest; only animate while actively dragging
                        .scaleEffect(page == cp ? (dragOffset == 0 ? 1.0 : exitScale) : (dragOffset == 0 ? 1.0 : enterScale))
                        .opacity(page == cp ? (dragOffset == 0 ? 1.0 : exitOpacity) : (dragOffset == 0 ? 1.0 : enterOpacity))
                    }
                }
                .offset(x: -CGFloat(cp) * Grid.panelW + dragOffset)
                .animation(dragOffset == 0 ? .interpolatingSpring(stiffness: 200, damping: 22) : nil, value: currentPage)
                .animation(dragOffset == 0 ? .interpolatingSpring(stiffness: 200, damping: 22) : nil, value: dragOffset)
                .gesture(DragGesture()
                    .onChanged { v in
                        let raw = v.translation.width
                        dragOffset = (cp == 0 && raw > 0) || (cp == pageCount - 1 && raw < 0)
                            ? raw / 3 : raw
                    }
                    .onEnded { v in
                        let threshold = Grid.panelW * 0.2
                        if v.translation.width < -threshold && cp < pageCount - 1 {
                            currentPage = cp + 1; focusedIndex = nil
                        } else if v.translation.width > threshold && cp > 0 {
                            currentPage = cp - 1; focusedIndex = nil
                        }
                        withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) { dragOffset = 0 }
                    }
                )
            }
            .frame(width: Grid.panelW, height: Grid.gridH)
            .clipped()

            // Page dots
            if pageCount > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { i in
                        Circle()
                            .fill(i == cp ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: cp)
                    }
                }
                .frame(height: Grid.dotsH)
            } else {
                Spacer().frame(height: Grid.dotsH)
            }
        }
    }

    // MARK: - Scroll handler (NSEvent.phase-based, one swipe = one page)
    
    private func handleScrollEvent(_ event: NSEvent) {
        let apps      = appEnumerator.sortedApps
        let pageCount = max(1, Int(ceil(Double(apps.count) / Double(perPage))))
        let cp        = min(currentPage, pageCount - 1)
        
        let phase = event.phase
        let ss = scrollState
        
        // --- Trackpad gesture lifecycle ---
        if phase.contains(.began) {
            ss.isGestureActive = true
            ss.gestureHandled = false
            ss.scrollAccumX = 0
            ss.scrollAccumY = 0
        }
        
        if ss.isGestureActive {
            ss.scrollAccumX += event.scrollingDeltaX
            ss.scrollAccumY += event.scrollingDeltaY
            
            if !ss.gestureHandled {
                let useH = abs(ss.scrollAccumX) >= abs(ss.scrollAccumY)
                let delta = useH ? ss.scrollAccumX : ss.scrollAccumY
                let threshold: CGFloat = 30
                
                if delta > threshold && cp > 0 {
                    ss.gestureHandled = true
                    withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) { currentPage = cp - 1 }
                    focusedIndex = nil
                } else if delta < -threshold && cp < pageCount - 1 {
                    ss.gestureHandled = true
                    withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) { currentPage = cp + 1 }
                    focusedIndex = nil
                }
            }
            
            if phase.contains(.ended) || phase.contains(.cancelled) {
                ss.isGestureActive = false
                ss.gestureHandled = false
                ss.scrollAccumX = 0
                ss.scrollAccumY = 0
            }
            return
        }
        
        // --- Mouse wheel (no phase info) ---
        if phase.isEmpty && event.momentumPhase.isEmpty {
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            let useH = abs(dx) >= abs(dy)
            let delta = useH ? dx : dy
            
            guard abs(delta) > 2 else { return }
            
            if !ss.mouseWheelLocked {
                ss.mouseWheelLocked = true
                if delta > 0 && cp > 0 {
                    withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) { currentPage = cp - 1 }
                    focusedIndex = nil
                } else if delta < 0 && cp < pageCount - 1 {
                    withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) { currentPage = cp + 1 }
                    focusedIndex = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ss.mouseWheelLocked = false
                }
            }
        }
    }

    private func handleKey(_ keyCode: UInt16) {
        let apps      = appEnumerator.sortedApps
        let pageCount = max(1, Int(ceil(Double(apps.count) / Double(perPage))))
        let cp        = min(currentPage, pageCount - 1)
        let pageStart = cp * perPage
        let pageEnd   = min(pageStart + perPage, apps.count)
        let pageSize  = pageEnd - pageStart

        var idx = focusedIndex ?? pageStart
        if idx < pageStart || idx >= pageEnd { idx = pageStart }
        let local = idx - pageStart

        switch keyCode {
        case 123: // ←
            if local > 0 {
                focusedIndex = pageStart + local - 1
            } else if cp > 0 {
                currentPage = cp - 1; focusedIndex = nil
            }
        case 124: // →
            if local < pageSize - 1 {
                focusedIndex = pageStart + local + 1
            } else if cp < pageCount - 1 {
                currentPage = cp + 1; focusedIndex = nil
            }
        case 126: // ↑
            let prev = local - Grid.cols
            if prev >= 0 {
                focusedIndex = pageStart + prev
            } else if cp > 0 {
                currentPage = cp - 1
                let prevStart = (cp - 1) * perPage
                let prevSize  = min(perPage, apps.count - prevStart)
                let col       = local % Grid.cols
                let lastRow   = (prevSize - 1) / Grid.cols
                focusedIndex  = prevStart + min(lastRow * Grid.cols + col, prevSize - 1)
            }
        case 125: // ↓
            let next = local + Grid.cols
            if next < pageSize {
                focusedIndex = pageStart + next
            } else if cp < pageCount - 1 {
                currentPage  = cp + 1
                focusedIndex = (cp + 1) * perPage + (local % Grid.cols)
            }
        case 36, 76: // Return / numpad Enter
            if let fi = focusedIndex, fi < apps.count {
                let app = apps[fi]
                appEnumerator.recordClick(appId: app.id)
                NSWorkspace.shared.open(app.url)
            }
        default: break
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().scaleEffect(0.8)
            Text("Loading apps...").font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass").font(.system(size: 28)).foregroundColor(.secondary.opacity(0.5))
            Text("No apps found").font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - App Item View

struct AppItemView: View {
    let app: InstalledApp
    let isHovered: Bool

    @ViewBuilder
    private var iconView: some View {
        if let cgImage = app.icon.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            Image(decorative: cgImage, scale: 1.0)
                .interpolation(.high)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(nsImage: app.icon)
                .interpolation(.high)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            iconView
                .frame(width: Grid.iconSize, height: Grid.iconSize)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)

            Text(app.name)
                .font(.system(size: 10, weight: isHovered ? .medium : .regular))
                .foregroundColor(isHovered ? .black : .black.opacity(0.75))
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(width: Grid.tileSize)
        }
        .contentShape(Rectangle())
        .cursor(.pointingHand)
    }
}

// MARK: - Cursor Helper

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in if inside { cursor.push() } else { NSCursor.pop() } }
    }
}
