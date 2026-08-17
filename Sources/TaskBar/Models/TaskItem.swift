import Foundation

struct TaskItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var notes: String
    var deadline: Date
    var remind: Bool
    var isDaily: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String,
        deadline: Date,
        remind: Bool,
        isDaily: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.deadline = Calendar.current.startOfDay(for: deadline)
        self.remind = remind
        self.isDaily = isDaily
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, deadline, remind, isDaily, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decode(String.self, forKey: .notes)
        deadline = try container.decode(Date.self, forKey: .deadline)
        remind = try container.decode(Bool.self, forKey: .remind)
        isDaily = try container.decodeIfPresent(Bool.self, forKey: .isDaily) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func isOverdue(on day: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !isDaily else { return false }
        return deadline < calendar.startOfDay(for: day)
    }

    func isDueToday(on day: Date = Date(), calendar: Calendar = .current) -> Bool {
        if isDaily { return true }
        return calendar.isDate(deadline, inSameDayAs: day)
    }
}
