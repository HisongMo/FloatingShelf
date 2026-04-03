import Foundation
import Combine

class FileStorageManager: ObservableObject {
    static let shared = FileStorageManager()
    
    @Published var files: [ShelfFile] = []
    @Published var hoveredFileId: UUID?
    @Published var isEditingNote = false
    
    private let storageKey = "shelfFiles"
    
    private init() {
        loadFiles()
    }
    
    func addFile(url: URL) {
        guard !files.contains(where: { $0.path == url.path }) else { return }
        let file = ShelfFile(url: url)
        files.append(file)
        saveFiles()
    }
    
    func addFiles(urls: [URL]) {
        for url in urls {
            addFile(url: url)
        }
    }
    
    func removeFile(_ file: ShelfFile) {
        files.removeAll { $0.id == file.id }
        saveFiles()
    }
    
    func updateNote(_ note: String?, for fileId: UUID) {
        if let index = files.firstIndex(where: { $0.id == fileId }) {
            files[index].customNote = note
            saveFiles()
        }
    }
    
    func removeFile(at index: Int) {
        guard index >= 0 && index < files.count else { return }
        files.remove(at: index)
        saveFiles()
    }
    
    func clearAll() {
        files.removeAll()
        saveFiles()
    }
    
    func cleanupMissing() {
        files.removeAll { !$0.exists }
        saveFiles()
    }
    
    // MARK: - Persistence
    
    private func saveFiles() {
        if let data = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadFiles() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ShelfFile].self, from: data) else { return }
        files = saved.filter { $0.exists }
    }
}
