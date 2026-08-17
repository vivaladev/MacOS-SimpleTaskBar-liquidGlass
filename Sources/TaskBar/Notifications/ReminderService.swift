import Foundation
import UserNotifications

@MainActor
final class ReminderService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderService()

    private let center = UNUserNotificationCenter.current()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override private init() {
        super.init()
    }

    func configure() {
        center.delegate = self
        Task { await refreshStatus() }
    }

    func requestAccess() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Keep going; the UI shows a hint if permission is missing.
        }
        await refreshStatus()
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    var isAllowed: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    func sync(tasks: [TaskItem]) async {
        await refreshStatus()
        center.removeAllPendingNotificationRequests()
        guard isAllowed else { return }

        for task in tasks where task.remind {
            if let request = makeRequest(for: task) {
                try? await center.add(request)
            }
        }
    }

    func cancel(id: UUID) {
        let key = identifier(for: id)
        center.removePendingNotificationRequests(withIdentifiers: [key])
        center.removeDeliveredNotifications(withIdentifiers: [key])
    }

    private func identifier(for id: UUID) -> String {
        "task.\(id.uuidString)"
    }

    private func makeRequest(for task: TaskItem) -> UNNotificationRequest? {
        guard let trigger = makeTrigger(for: task) else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = task.title
        content.sound = .default
        if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.subtitle = task.notes
        }
        content.userInfo = ["taskId": task.id.uuidString]

        return UNNotificationRequest(
            identifier: identifier(for: task.id),
            content: content,
            trigger: trigger
        )
    }

    /// Daily: every day at 09:00. One-shot: 09:00 on the deadline day (or in a minute if that already passed today).
    private func makeTrigger(for task: TaskItem) -> UNNotificationTrigger? {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0

        if task.isDaily {
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: task.deadline)
        var dated = calendar.dateComponents([.year, .month, .day], from: start)
        dated.hour = 9
        dated.minute = 0

        guard let fireDate = calendar.date(from: dated) else { return nil }

        if fireDate > Date() {
            return UNCalendarNotificationTrigger(dateMatching: dated, repeats: false)
        }

        if calendar.isDateInToday(start) {
            return UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        }

        return nil
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
