import Foundation

struct ImageFile: Identifiable {
    let id = UUID()
    let fileName: String
    let filePath: URL
    let createdAt: Date

}
