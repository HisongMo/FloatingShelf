import SwiftUI
import UniformTypeIdentifiers

struct FileShelfView: View {
    @EnvironmentObject var storage: FileStorageManager
    @State private var isTargeted = false
    @State private var editingFileId: UUID?
    @State private var editingNoteText = ""
    @AppStorage("glassBackgroundColor") private var glassBackgroundColor = "black"
    
    private let columns = [
        GridItem(.adaptive(minimum: 72, maximum: 80), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            ZStack {
                // Base Glass
                Color(glassBackgroundColor == "white" ? .white : .black)
                    .opacity(glassBackgroundColor == "white" ? 0.3 : 0.6)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .tint(glassBackgroundColor == "white" ? .white : .black)
                    .id(glassBackgroundColor)
                    
                    // Liquid Sheen 1
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.1), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Liquid Sheen 2 & Gloss
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (glassBackgroundColor == "white" ? Color.white : Color.white).opacity(0.3),
                                    .clear,
                                    (glassBackgroundColor == "white" ? Color.black : Color.white).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                    
                    // Dynamic Border
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            isTargeted
                                ? LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [
                                    Color.secondary.opacity(0.4),
                                    Color.secondary.opacity(0.1),
                                    Color.secondary.opacity(0.2),
                                    Color.secondary.opacity(0.4)
                                  ], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isTargeted ? 2.5 : 1.5
                        )
                }
            
                // Content
                if storage.files.isEmpty {
                    emptyState
                } else {
                    fileGrid
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(minWidth: 120, maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .alert("Edit Note", isPresented: $storage.isEditingNote) {
            TextField("Note", text: $editingNoteText)
                .onAppear {
                    // Activate TextField when alert shows
                    NSApp.activate(ignoringOtherApps: true)
                }
            Button("Save") {
                if let id = editingFileId {
                    storage.updateNote(editingNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingNoteText, for: id)
                }
                editingFileId = nil
            }
            Button("Cancel", role: .cancel) {
                editingFileId = nil
            }
        } message: {
            Text("Enter a custom display name or note for this item. Leave empty to use the original filename.")
        }
        .onChange(of: storage.isEditingNote) { isEditing in
            if !isEditing {
                if !HotkeyManager.shared.fileShelfActive {
                    // Tell AppDelegate to hide the panel
                    NotificationCenter.default.post(name: NSNotification.Name("HideFileShelf"), object: nil)
                }
            }
        }
        .environment(\.colorScheme, glassBackgroundColor == "white" ? .light : .dark)
    }
    
    // MARK: - File Grid
    
    private var fileGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(storage.files) { file in
                    FileItemView(file: file, isHovered: storage.hoveredFileId == file.id)
                        .onHover { isHovered in
                            storage.hoveredFileId = isHovered ? file.id : nil
                        }
                        .onDrag {
                            NSItemProvider(contentsOf: file.url) ?? NSItemProvider()
                        }
                        .contextMenu {
                            Button(file.customNote == nil ? "Add Note..." : "Edit Note...") {
                                editingFileId = file.id
                                editingNoteText = file.customNote ?? file.name
                                storage.isEditingNote = true
                            }
                            Divider()
                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([file.url])
                            }
                            Button("Open") {
                                NSWorkspace.shared.open(file.url)
                            }
                            Divider()
                            Button("Remove", role: .destructive) {
                                withAnimation(.spring(response: 0.3)) {
                                    storage.removeFile(file)
                                }
                            }
                        }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.never)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(isTargeted ? .purple : .secondary.opacity(0.4))
                    .frame(width: 200, height: 100)
                
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            isTargeted
                                ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.secondary.opacity(0.5), .secondary.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                    Text("Drop files here")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isTargeted)
            
            Spacer()
        }
    }
    
    // MARK: - Drop Handling
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3)) {
                            storage.addFile(url: url)
                        }
                    }
                    handled = true
                }
            }
        }
        return handled
    }
}

// MARK: - File Item View

struct FileItemView: View {
    let file: ShelfFile
    let isHovered: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var isLight: Bool { colorScheme == .light }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Glass tile background dynamically adjusting for light/dark
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isLight ? Color.black.opacity(isHovered ? 0.08 : 0.03) : Color.white.opacity(isHovered ? 0.2 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isLight ? Color.black.opacity(isHovered ? 0.15 : 0.05) : Color.white.opacity(isHovered ? 0.4 : 0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isLight ? 0.05 : 0.15), radius: isHovered ? 8 : 0, y: isHovered ? 4 : 0)
                    .frame(width: 64, height: 64)
                    
                // Glow behind icon
                if isHovered {
                    Circle()
                        .fill(Color.blue.opacity(isLight ? 0.2 : 0.4))
                        .blur(radius: 12)
                        .frame(width: 40, height: 40)
                }
                
                fileIcon
                    .frame(width: 48, height: 48)
                    .scaleEffect(isHovered ? 1.15 : 1.0)
                    .shadow(color: Color.black.opacity(isLight ? 0.15 : 0.4), radius: isHovered ? 5 : 2, y: isHovered ? 3 : 1)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            
            Text(file.displayName)
                .font(.system(size: 11, weight: isHovered ? .medium : .regular))
                .foregroundColor(isHovered ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .opacity(file.exists ? 1 : 0.4)
    }
    
    @ViewBuilder
    private var fileIcon: some View {
        let icon = NSWorkspace.shared.icon(forFile: file.path)
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
