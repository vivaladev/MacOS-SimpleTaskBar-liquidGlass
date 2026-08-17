import Foundation

struct BackupDocument: Codable, Sendable {
    static let currentFormat = "taskbar.backup"
    static let currentVersion = 1

    var format: String
    var version: Int
    var exportedAt: Date
    var tasks: [TaskItem]
    var files: [String: Data]

    init(tasks: [TaskItem], files: [String: Data], exportedAt: Date = Date()) {
        self.format = Self.currentFormat
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.tasks = tasks
        self.files = files
    }
}
