import Foundation
import Observation

@Observable
@MainActor
final class TaskStore {
    private(set) var tasks: [TaskItem] = []
    private(set) var notificationsAllowed = false
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

    func add(title: String, notes: String, deadline: Date, remind: Bool, isDaily: Bool) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let item = TaskItem(
            title: trimmedTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            deadline: isDaily ? Date() : deadline,
            remind: remind,
            isDaily: isDaily
        )
        tasks.append(item)
        persistAndSync()
    }

    func delete(_ item: TaskItem) {
        tasks.removeAll { $0.id == item.id }
        ReminderService.shared.cancel(id: item.id)
        persistAndSync()
    }

    func toggleRemind(_ item: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == item.id }) else { return }
        tasks[index].remind.toggle()
        persistAndSync()
    }

    private func persistAndSync() {
        save()
        Task { await ReminderService.shared.sync(tasks: tasks) }
        notificationsAllowed = ReminderService.shared.isAllowed
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
            // Local persistence failure is non-fatal; the in-memory list still works this session.
        }
    }
}
