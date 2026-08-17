import Foundation

enum ReminderFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case oncePerDay
    case everyHour
    case every30
    case every15
    case every5

    var id: String { rawValue }

    var intervalMinutes: Int {
        switch self {
        case .oncePerDay: 0
        case .everyHour: 60
        case .every30: 30
        case .every15: 15
        case .every5: 5
        }
    }

    var title: String {
        switch self {
        case .oncePerDay: "Раз в день"
        case .everyHour: "Каждый час"
        case .every30: "Каждые 30 мин"
        case .every15: "Каждые 15 мин"
        case .every5: "Каждые 5 мин"
        }
    }

    var subtitle: String {
        switch self {
        case .oncePerDay: "один тост в начале окна"
        case .everyHour: "мягко"
        case .every30: "настойчиво"
        case .every15: "часто"
        case .every5: "задолбать"
        }
    }
}

struct ReminderSchedule: Codable, Hashable, Sendable {
    var frequency: ReminderFrequency
    var startHour: Int
    var endHour: Int

    static let `default` = ReminderSchedule(frequency: .every15, startHour: 9, endHour: 22)

    var summary: String {
        let window = String(format: "%02d:00–%02d:00", startHour, endHour)
        return "\(frequency.title) · \(window)"
    }

    func clamped() -> ReminderSchedule {
        var copy = self
        copy.startHour = min(max(startHour, 0), 23)
        copy.endHour = min(max(endHour, copy.startHour + 1), 24)
        return copy
    }
}
