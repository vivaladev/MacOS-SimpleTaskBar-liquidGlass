import AppKit
import Foundation

@MainActor
final class AttachmentStore {
    static let shared = AttachmentStore()

    let root: URL

    private init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("TaskBar", isDirectory: true)
                .appendingPathComponent("attachments", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.root = folder
        }
    }

    func folder(for taskID: UUID) -> URL {
        root.appendingPathComponent(taskID.uuidString, isDirectory: true)
    }

    func url(for attachment: TaskAttachment, taskID: UUID) -> URL {
        folder(for: taskID).appendingPathComponent(attachment.filename)
    }

    func save(jpeg: Data, to taskID: UUID) -> TaskAttachment? {
        let attachment = TaskAttachment()
        let dir = folder(for: taskID)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try jpeg.write(to: url(for: attachment, taskID: taskID), options: [.atomic])
            return attachment
        } catch {
            return nil
        }
    }

    func image(for attachment: TaskAttachment, taskID: UUID) -> NSImage? {
        NSImage(contentsOf: url(for: attachment, taskID: taskID))
    }

    func data(for attachment: TaskAttachment, taskID: UUID) -> Data? {
        try? Data(contentsOf: url(for: attachment, taskID: taskID))
    }

    func delete(_ attachment: TaskAttachment, taskID: UUID) {
        try? FileManager.default.removeItem(at: url(for: attachment, taskID: taskID))
    }

    func deleteAll(for taskID: UUID) {
        try? FileManager.default.removeItem(at: folder(for: taskID))
    }

    func write(data: Data, attachment: TaskAttachment, taskID: UUID) {
        let dir = folder(for: taskID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url(for: attachment, taskID: taskID), options: [.atomic])
    }

    func backupKey(taskID: UUID, attachment: TaskAttachment) -> String {
        "\(taskID.uuidString)/\(attachment.filename)"
    }
}
