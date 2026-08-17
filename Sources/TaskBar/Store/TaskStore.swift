import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class TaskStore {
    private(set) var tasks: [TaskItem] = []
    private(set) var notificationsAllowed = false
    var toast: String?
    var hoveredTaskID: UUID?
    var editingTaskID: UUID?
    var composerImages: [Data] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var sortedTasks: [TaskItem] {
        tasks.sorted { lhs, rhs in
            let leftKey = lhs.isDaily ? Calendar.current.startOfDay(for: Date()) : lhs.deadline
            let rightKey = rhs.isDaily ? Calendar.current.startOfDay(for: Date()) : rhs.deadline
            if leftKey != rightKey {
                return leftKey < rightKey
            }
            if lhs.isDaily != rhs.isDaily {
                return lhs.isDaily && !rhs.isDaily
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var overdueCount: Int {
        tasks.filter { $0.isOverdue() }.count
    }

    init(fileURL: URL? = nil) {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let fileURL {
            self.fileURL = fileURL
        } else {
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("TaskBar", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.fileURL = folder.appendingPathComponent("tasks.json")
        }

        load()
    }

    func bootstrap() async {
        await ReminderService.shared.requestAccess()
        await ReminderService.shared.refreshStatus()
        notificationsAllowed = ReminderService.shared.isAllowed
        await ReminderService.shared.sync(tasks: tasks)
    }

    func add(
        title: String,
        notes: String,
        deadline: Date,
        remind: Bool,
        isDaily: Bool,
        schedule: ReminderSchedule,
        images: [Data]
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let item = TaskItem(
            title: trimmedTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            deadline: isDaily ? Date() : deadline,
            remind: remind,
            isDaily: isDaily,
            schedule: schedule
        )
        tasks.append(item)
        for jpeg in images.prefix(ImageCodec.maxAttachments) {
            _ = addImage(jpeg, to: item.id, persist: false)
        }
        composerImages = []
        persistAndSync()
    }

    func delete(_ item: TaskItem) {
        if editingTaskID == item.id {
            editingTaskID = nil
        }
        tasks.removeAll { $0.id == item.id }
        AttachmentStore.shared.deleteAll(for: item.id)
        ReminderService.shared.cancel(id: item.id)
        persistAndSync()
    }

    func toggleRemind(_ item: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == item.id }) else { return }
        tasks[index].remind.toggle()
        persistAndSync()
    }

    func beginEditing(_ item: TaskItem) {
        editingTaskID = item.id
    }

    func cancelEditing() {
        editingTaskID = nil
    }

    func update(
        id: UUID,
        title: String,
        notes: String,
        deadline: Date,
        remind: Bool,
        isDaily: Bool,
        schedule: ReminderSchedule
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        tasks[index].title = trimmedTitle
        tasks[index].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks[index].isDaily = isDaily
        tasks[index].deadline = Calendar.current.startOfDay(for: isDaily ? Date() : deadline)
        tasks[index].remind = remind
        tasks[index].schedule = schedule.clamped()
        editingTaskID = nil
        persistAndSync()
        flash("Сохранено")
    }

    func ingestPastedImages() {
        let images = ImageCodec.jpegData(from: .general)
        guard !images.isEmpty else { return }
        if let hoveredTaskID {
            for jpeg in images {
                _ = addImage(jpeg, to: hoveredTaskID)
            }
            return
        }
        for jpeg in images {
            guard composerImages.count < ImageCodec.maxAttachments else { break }
            composerImages.append(jpeg)
        }
    }

    @discardableResult
    func addImage(_ jpeg: Data, to taskID: UUID, persist: Bool = true) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        guard tasks[index].attachments.count < ImageCodec.maxAttachments else { return false }
        guard let attachment = AttachmentStore.shared.save(jpeg: jpeg, to: taskID) else { return false }
        tasks[index].attachments.append(attachment)
        if persist { persistAndSync() }
        return true
    }

    func removeAttachment(_ attachment: TaskAttachment, from taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].attachments.removeAll { $0.id == attachment.id }
        AttachmentStore.shared.delete(attachment, taskID: taskID)
        persistAndSync()
    }

    func exportBackup() {
        FilePanel.save({ panel in
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [UTType(filenameExtension: "taskbarbackup") ?? .json]
            panel.nameFieldStringValue = "TaskBar-\(Self.stamp()).taskbarbackup"
            panel.title = "Экспорт задач"
            panel.prompt = "Сохранить"
        }) { url in
            guard let url else { return }
            do {
                let data = try self.makeBackupData()
                try data.write(to: url, options: [.atomic])
                self.flash("Экспорт готов")
            } catch {
                self.flash("Не удалось экспортировать")
            }
        }
    }

    func importBackup() {
        FilePanel.open({ panel in
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [UTType(filenameExtension: "taskbarbackup") ?? .json, .json]
            panel.title = "Импорт задач"
            panel.prompt = "Импортировать"
        }) { panel, ok in
            guard ok, let url = panel.url else { return }
            do {
                let added = try self.mergeBackup(from: url)
                self.flash(added == 0 ? "Новых задач нет" : "Импортировано: \(added)")
            } catch {
                self.flash("Файл импорта не подходит")
            }
        }
    }

    private func makeBackupData() throws -> Data {
        var files: [String: Data] = [:]
        for task in tasks {
            for attachment in task.attachments {
                let key = AttachmentStore.shared.backupKey(taskID: task.id, attachment: attachment)
                if let data = AttachmentStore.shared.data(for: attachment, taskID: task.id) {
                    files[key] = data
                }
            }
        }
        let document = BackupDocument(tasks: tasks, files: files)
        return try encoder.encode(document)
    }

    private func mergeBackup(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let document = try decoder.decode(BackupDocument.self, from: data)
        guard document.format == BackupDocument.currentFormat else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let existing = Set(tasks.map(\.id))
        var added = 0
        for var task in document.tasks {
            if existing.contains(task.id) { continue }
            var kept: [TaskAttachment] = []
            for attachment in task.attachments {
                let key = AttachmentStore.shared.backupKey(taskID: task.id, attachment: attachment)
                if let blob = document.files[key] {
                    AttachmentStore.shared.write(data: blob, attachment: attachment, taskID: task.id)
                    kept.append(attachment)
                }
            }
            task.attachments = kept
            tasks.append(task)
            added += 1
        }
        persistAndSync()
        return added
    }

    private func persistAndSync() {
        save()
        Task { await ReminderService.shared.sync(tasks: tasks) }
        notificationsAllowed = ReminderService.shared.isAllowed
    }

    private func flash(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if toast == text { toast = nil }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            tasks = try decoder.decode([TaskItem].self, from: data)
        } catch {
            tasks = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(tasks)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // In-memory list still works this session.
        }
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
