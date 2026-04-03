import SwiftUI
import AppKit

// MARK: - Layout Constants
private enum Grid {
    static let cols        = 7
    static let rows        = 3
    static let tileSize:   CGFloat = 72
    static let iconSize:   CGFloat = 56
    static let labelH:     CGFloat = 20
    static let itemH:      CGFloat = tileSize + 6 + labelH   // 98
    static let colSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 12
    static let hPad:       CGFloat = 20
    static let vPad:       CGFloat = 16
    static let dotsH:      CGFloat = 22
    static let searchH:    CGFloat = 40  // search bar area height

    static let panelW: CGFloat = CGFloat(cols) * tileSize + CGFloat(cols - 1) * colSpacing + hPad * 2
    static let gridH:  CGFloat = CGFloat(rows) * itemH + CGFloat(rows - 1) * rowSpacing + vPad * 2
    static let panelH: CGFloat = searchH + gridH + dotsH
    
    static let perPage = cols * rows  // 21
}

// MARK: - Scroll State

private class ScrollState {
    var isGestureActive = false
    var gestureHandled = false
    var scrollAccumX: CGFloat = 0
    var scrollAccumY: CGFloat = 0
    var mouseWheelLocked = false
}

// MARK: - Page Direction

enum PageDirection {
    case prev, next
}

struct AppGridView: View {
    @EnvironmentObject var appEnumerator: AppEnumerator
    @AppStorage("glassBackgroundColor") private var glassBackgroundColor = "black"
    @State private var currentPage = 0
    @State private var scrollMonitor: Any? = nil
    @State private var keyMonitor: Any? = nil
    // Track slide direction for transition
    @State private var slideForward = true
    // Search
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isSearchActivated = false

    private let scrollState = ScrollState()
    
    private var isLight: Bool { glassBackgroundColor == "white" }
    private var dotColor: Color { isLight ? .black : .white }
    
    /// Filtered apps based on search text
    private var filteredApps: [InstalledApp] {
        let allApps = appEnumerator.sortedApps
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allApps }
        return allApps.filter { app in
            app.name.localizedCaseInsensitiveContains(query)
            || (app.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        let apps      = filteredApps
        let pageCount = max(1, Int(ceil(Double(apps.count) / Double(Grid.perPage))))
        let cp        = min(currentPage, pageCount - 1)
        
        ZStack {
            // Liquid Glass Background
            ZStack {
                // Base Glass
                Color(isLight ? NSColor.white : NSColor.black)
                    .opacity(isLight ? 0.25 : 0.45)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .tint(isLight ? .white : .black)
                    .id(glassBackgroundColor)
                
                // Liquid Sheen 1
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.12), Color.blue.opacity(0.08), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Liquid Sheen 2 & Gloss
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                .clear,
                                Color.white.opacity(isLight ? 0.05 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
                
                // Dynamic Border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.secondary.opacity(0.35),
                                Color.secondary.opacity(0.08),
                                Color.secondary.opacity(0.15),
                                Color.secondary.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }

            if appEnumerator.isLoading {
                loadingState
            } else if apps.isEmpty && searchText.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    // MARK: - Search Bar
                    searchBar
                        .frame(height: Grid.searchH)
                    
                    if apps.isEmpty {
                        // No results state
                        noResultsState
                            .frame(width: Grid.panelW, height: Grid.gridH)
                    } else {
                        // Only render the CURRENT page — simple, no offset bugs
                        pageView(apps: apps, page: cp, pageCount: pageCount)
                            .frame(width: Grid.panelW, height: Grid.gridH)
                            .clipped()
                            .id(cp) // force view identity change on page flip
                            .transition(.asymmetric(
                                insertion: .move(edge: slideForward ? .trailing : .leading),
                                removal: .move(edge: slideForward ? .leading : .trailing)
                            ))
                    }
                    
                    // Page dots
                    if pageCount > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<pageCount, id: \.self) { i in
                                Circle()
                                    .fill(i == cp ? dotColor.opacity(0.75) : dotColor.opacity(0.25))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(height: Grid.dotsH)
                    } else {
                        Spacer().frame(height: Grid.dotsH)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(width: Grid.panelW, height: Grid.panelH)
        .environment(\.controlActiveState, .active)
        .environment(\.colorScheme, isLight ? .light : .dark)
        .onAppear {
            installEventMonitors()
            searchText = ""
            currentPage = 0
            isSearchActivated = false
            isSearchFocused = false
            appEnumerator.isSearching = false
        }
        .onDisappear {
            removeEventMonitors()
            searchText = ""
            currentPage = 0
        }
        .onChange(of: searchText) { _ in
            // Reset to first page when search changes
            currentPage = 0
        }
        .onChange(of: isSearchFocused) { focused in
            appEnumerator.isSearching = focused
        }
        .onChange(of: appEnumerator.isSearching) { isSearching in
            // When AppDelegate tells us we're no longer searching (usually hidden),
            // reset everything so the next show starts fresh.
            if !isSearching {
                searchText = ""
                isSearchActivated = false
                isSearchFocused = false
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("搜索", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .focused($isSearchFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(height: 26)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.15),
                            lineWidth: 0.5
                        )
                )
        }
        .frame(width: 200)
        .padding(.top, 10)
        .opacity(isSearchActivated || !searchText.isEmpty ? 1.0 : 0.4)
        .saturation(isSearchActivated || !searchText.isEmpty ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.2), value: isSearchActivated || !searchText.isEmpty)
    }

    // MARK: - Single Page View
    
    private func pageView(apps: [InstalledApp], page: Int, pageCount: Int) -> some View {
        let start    = page * Grid.perPage
        let end      = min(start + Grid.perPage, apps.count)
        let pageApps = Array(apps[start..<end])
        
        let rows = stride(from: 0, to: pageApps.count, by: Grid.cols).map { s in
            Array(pageApps[s..<min(s + Grid.cols, pageApps.count)])
        }
        
        return VStack(spacing: Grid.rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, rowApps in
                HStack(spacing: Grid.colSpacing) {
                    ForEach(rowApps, id: \.id) { app in
                        AppItemView(
                            app: app,
                            isHovered: appEnumerator.hoveredAppId == app.id
                        )
                        .frame(width: Grid.tileSize)
                        .onHover { h in appEnumerator.hoveredAppId = h ? app.id : nil }
                        .onTapGesture {
                            appEnumerator.recordClick(appId: app.id)
                            NSWorkspace.shared.open(app.url)
                            NotificationCenter.default.post(name: NSNotification.Name("HideAppLauncher"), object: nil)
                        }
                    }
                    // Fill empty slots in last row
                    if rowApps.count < Grid.cols {
                        ForEach(0..<(Grid.cols - rowApps.count), id: \.self) { _ in
                            Color.clear.frame(width: Grid.tileSize)
                        }
                    }
                }
            }
            // Fill empty rows if page has fewer than 3 rows
            if rows.count < Grid.rows {
                ForEach(0..<(Grid.rows - rows.count), id: \.self) { _ in
                    HStack(spacing: Grid.colSpacing) {
                        ForEach(0..<Grid.cols, id: \.self) { _ in
                            Color.clear.frame(width: Grid.tileSize, height: Grid.itemH)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Grid.hPad)
        .padding(.vertical, Grid.vPad)
    }

    // MARK: - Page navigation
    
    private func goToPage(_ direction: PageDirection) {
        let apps      = filteredApps
        let pageCount = max(1, Int(ceil(Double(apps.count) / Double(Grid.perPage))))
        let cp        = min(currentPage, pageCount - 1)
        
        switch direction {
        case .prev:
            guard cp > 0 else { return }
            slideForward = false
            withAnimation(.easeInOut(duration: 0.25)) { currentPage = cp - 1 }
        case .next:
            guard cp < pageCount - 1 else { return }
            slideForward = true
            withAnimation(.easeInOut(duration: 0.25)) { currentPage = cp + 1 }
        }
    }

    // MARK: - Event Monitors

    private func installEventMonitors() {
        if scrollMonitor == nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
                self.handleScrollEvent(event)
                return event
            }
        }
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                // Arrow keys for page navigation
                if event.keyCode == 123 { // ←
                    self.goToPage(.prev); return nil
                } else if event.keyCode == 124 { // →
                    self.goToPage(.next); return nil
                }
                
                // K to activate search
                if event.keyCode == 40 { // K
                    if !isSearchActivated {
                        DispatchQueue.main.async {
                            isSearchActivated = true
                            isSearchFocused = true
                        }
                        return nil
                    }
                }
                
                // Escape to clear search or hide panel
                if event.keyCode == 53 { // Escape
                    if !searchText.isEmpty {
                        DispatchQueue.main.async { searchText = "" }
                        return nil
                    } else if isSearchActivated {
                        DispatchQueue.main.async { isSearchActivated = false }
                        return nil
                    } else {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("HideAppLauncher"), object: nil)
                        }
                        return nil
                    }
                }
                
                // Delete/Backspace
                if event.keyCode == 51 { // Delete
                    if !searchText.isEmpty {
                        DispatchQueue.main.async {
                            searchText = String(searchText.dropLast())
                        }
                        return nil
                    }
                    return event
                }
                
                // Any printable character → append to search (Launchpad behavior)
                if let chars = event.characters, !chars.isEmpty,
                   !event.modifierFlags.contains(.command),
                   !event.modifierFlags.contains(.control) {
                    let printable = chars.filter { !$0.isNewline && $0 != "\t" }
                    if !printable.isEmpty {
                        DispatchQueue.main.async {
                            searchText += printable
                            isSearchActivated = true
                            isSearchFocused = true
                        }
                        return nil
                    }
                }
                
                return event
            }
        }
    }

    private func removeEventMonitors() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    // MARK: - Scroll handler

    private func handleScrollEvent(_ event: NSEvent) {
        let phase = event.phase
        let ss = scrollState

        // Trackpad gesture
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

                if delta > threshold {
                    ss.gestureHandled = true
                    goToPage(.prev)
                } else if delta < -threshold {
                    ss.gestureHandled = true
                    goToPage(.next)
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

        // Mouse wheel
        if phase.isEmpty && event.momentumPhase.isEmpty {
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            let useH = abs(dx) >= abs(dy)
            let delta = useH ? dx : dy
            guard abs(delta) > 2 else { return }

            if !ss.mouseWheelLocked {
                ss.mouseWheelLocked = true
                if delta > 0 { goToPage(.prev) } else { goToPage(.next) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ss.mouseWheelLocked = false
                }
            }
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
    
    private var noResultsState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "app.dashed")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(.secondary.opacity(0.5))
            Text("无搜索结果")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("尝试搜索其他关键词")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
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

    @Environment(\.colorScheme) var colorScheme
    private var isLight: Bool { colorScheme == .light }

    var body: some View {
        VStack(spacing: 4) {
            iconView
                .frame(width: Grid.iconSize, height: Grid.iconSize)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .shadow(color: Color.black.opacity(isLight ? 0.1 : 0.35), radius: isHovered ? 6 : 2, y: isHovered ? 3 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)

            Text(app.name)
                .font(.system(size: 10, weight: isHovered ? .medium : .regular))
                .foregroundColor(isHovered ? .primary : .primary.opacity(0.75))
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
