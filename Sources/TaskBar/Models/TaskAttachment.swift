import Foundation

struct TaskAttachment: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var createdAt: Date

    init(id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
    }

    var filename: String {
        "\(id.uuidString).jpg"
    }
}
