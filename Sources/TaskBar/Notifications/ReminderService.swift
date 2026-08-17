import AppKit
import Foundation
import UserNotifications

@MainActor
final class ReminderService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderService()

    private let center = UNUserNotificationCenter.current()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private var refreshTimer: Timer?
    private var lastTasks: [TaskItem] = []

    private let maxPending = 60
    private let perTaskLimit = 10

    override private init() {
        super.init()
    }

    func configure() {
        center.delegate = self
        Task { await refreshStatus() }
        startTimer()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(resyncFromWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func requestAccess() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // UI shows a hint if permission is missing.
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
        lastTasks = tasks
        await refreshStatus()
        center.removeAllPendingNotificationRequests()
        guard isAllowed else { return }

        var remaining = maxPending
        let now = Date()
        for task in tasks where task.remind {
            let limit = min(perTaskLimit, remaining)
            let requests = makeRequests(for: task, now: now, limit: limit)
            remaining -= requests.count
            for request in requests {
                try? await center.add(request)
            }
            if remaining <= 0 { break }
        }
    }

    func cancel(id: UUID) {
        let prefix = identifierPrefix(for: id)
        let center = self.center
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    private func startTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 8 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.sync(tasks: self.lastTasks)
            }
        }
        refreshTimer?.tolerance = 30
    }

    @objc private func resyncFromWake() {
        Task { await sync(tasks: lastTasks) }
    }

    private func identifierPrefix(for id: UUID) -> String {
        "task.\(id.uuidString)."
    }

    private func makeRequests(for task: TaskItem, now: Date, limit: Int) -> [UNNotificationRequest] {
        let dates = nextFireDates(for: task, from: now, limit: limit)
        return dates.enumerated().compactMap { index, date in
            makeRequest(for: task, fireDate: date, index: index)
        }
    }

    private func makeRequest(for task: TaskItem, fireDate: Date, index: Int) -> UNNotificationRequest? {
        let interval = max(fireDate.timeIntervalSinceNow, 5)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = nagTitle(for: task, index: index)
        content.body = task.title
        content.sound = .default
        if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.subtitle = task.notes
        }
        content.userInfo = ["taskId": task.id.uuidString]
        content.interruptionLevel = .active

        if let first = task.attachments.first,
           let fileURL = copyAttachmentForNotification(first, taskID: task.id) {
            if let attachment = try? UNNotificationAttachment(
                identifier: first.id.uuidString,
                url: fileURL,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg"]
            ) {
                content.attachments = [attachment]
            }
        }

        return UNNotificationRequest(
            identifier: "\(identifierPrefix(for: task.id))\(index)",
            content: content,
            trigger: trigger
        )
    }

    private func nagTitle(for task: TaskItem, index: Int) -> String {
        if task.schedule.frequency == .every5 || task.schedule.frequency == .every15 {
            return index == 0 ? "Напоминание" : "Всё ещё не сделано"
        }
        return "Напоминание"
    }

    private func copyAttachmentForNotification(_ attachment: TaskAttachment, taskID: UUID) -> URL? {
        guard let data = AttachmentStore.shared.data(for: attachment, taskID: taskID) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("taskbar-\(taskID.uuidString)-\(attachment.id.uuidString).jpg")
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    func nextFireDates(for task: TaskItem, from now: Date, limit: Int) -> [Date] {
        let schedule = task.schedule.clamped()
        let calendar = Calendar.current
        var dates: [Date] = []
        let horizon = calendar.date(byAdding: .day, value: 14, to: now) ?? now.addingTimeInterval(14 * 86400)

        if schedule.frequency == .oncePerDay {
            var day = calendar.startOfDay(for: now)
            while dates.count < limit, day < horizon {
                if let fire = calendar.date(bySettingHour: schedule.startHour, minute: 0, second: 0, of: day),
                   fire > now {
                    dates.append(fire)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            if dates.isEmpty, isInWindow(now, schedule: schedule, calendar: calendar) {
                dates.append(now.addingTimeInterval(60))
            }
            return dates
        }

        let step = TimeInterval(max(schedule.frequency.intervalMinutes, 1) * 60)
        var cursor = alignedCursor(after: now, schedule: schedule, calendar: calendar)
        var guardCounter = 0
        while dates.count < limit, cursor < horizon, guardCounter < 4000 {
            guardCounter += 1
            if cursor > now, isInWindow(cursor, schedule: schedule, calendar: calendar) {
                dates.append(cursor)
            }
            cursor = cursor.addingTimeInterval(step)
            if !isInWindow(cursor, schedule: schedule, calendar: calendar) {
                cursor = nextWindowStart(after: cursor, schedule: schedule, calendar: calendar)
            }
        }
        return dates
    }

    private func isInWindow(_ date: Date, schedule: ReminderSchedule, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minutes = hour * 60 + minute
        return minutes >= schedule.startHour * 60 && minutes < schedule.endHour * 60
    }

    private func alignedCursor(after now: Date, schedule: ReminderSchedule, calendar: Calendar) -> Date {
        let stepMinutes = max(schedule.frequency.intervalMinutes, 1)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let remainder = minute % stepMinutes
        let add = remainder == 0 ? stepMinutes : (stepMinutes - remainder)
        var parts = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        parts.minute = minute + add
        parts.second = 0
        var candidate = calendar.date(from: parts) ?? now.addingTimeInterval(TimeInterval(add * 60))
        if hour < schedule.startHour || !isInWindow(candidate, schedule: schedule, calendar: calendar) {
            candidate = nextWindowStart(after: now, schedule: schedule, calendar: calendar)
        }
        return candidate
    }

    private func nextWindowStart(after date: Date, schedule: ReminderSchedule, calendar: Calendar) -> Date {
        let startToday = calendar.date(bySettingHour: schedule.startHour, minute: 0, second: 0, of: date) ?? date
        if date < startToday {
            return startToday
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86400)
        return calendar.date(bySettingHour: schedule.startHour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
