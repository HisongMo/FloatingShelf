import Foundation

struct ShelfFile: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let dateAdded: Date
    var customNote: String?
    
    var url: URL { URL(fileURLWithPath: path) }
    
    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    var fileExtension: String {
        url.pathExtension.lowercased()
    }
    
    var displayName: String {
        customNote ?? name
    }
    
    init(url: URL) {
        self.id = UUID()
        self.name = url.lastPathComponent
        self.path = url.path
        self.dateAdded = Date()
    }
}
