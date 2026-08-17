import SwiftUI

struct PanelView: View {
    @Environment(TaskStore.self) private var store

    private var todayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return "Сегодня, \(formatter.string(from: Date()))"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.hairline)

            taskList
                .frame(maxHeight: .infinity)

            Divider().overlay(Theme.hairline)

            ComposerView()
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            footer
        }
        .frame(width: Theme.panelWidth, height: Theme.panelHeight)
        .containerBackground(.clear, for: .window)
        .preferredColorScheme(.dark)
        .task {
            await store.bootstrap()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Задачи")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        Button {
                            Task { await store.bootstrap() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Обновить напоминания")

                        Button {
                            NSApp.terminate(nil)
                        } label: {
                            Image(systemName: "power")
                        }
                        .help("Выйти")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .labelStyle(.iconOnly)
                }
            }

            Text(todayTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if store.sortedTasks.isEmpty {
                    emptyState
                        .padding(.top, 48)
                } else {
                    ForEach(store.sortedTasks) { item in
                        TaskCardView(item: item)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .animation(.snappy(duration: 0.25), value: store.sortedTasks)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.accent.opacity(0.85))
            Text("Нет задач")
                .font(.system(size: 14, weight: .semibold))
            Text("Добавьте первую в форме ниже")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footer: some View {
        HStack {
            if !store.notificationsAllowed, store.tasks.contains(where: \.remind) {
                Text("Уведомления выключены в системе")
                    .foregroundStyle(Theme.overdue)
            } else {
                Text(footerSummary)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("v1.0.0")
                .foregroundStyle(Theme.muted.opacity(0.8))
        }
        .font(.system(size: 11))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var footerSummary: String {
        let total = store.tasks.count
        let overdue = store.overdueCount
        if total == 0 {
            return "Сохранено локально"
        }
        if overdue > 0 {
            return "\(total.tasksWord) · просрочено \(overdue)"
        }
        return "\(total.tasksWord) · сохранено локально"
    }
}

private extension Int {
    var tasksWord: String {
        let mod10 = self % 10
        let mod100 = self % 100
        if mod10 == 1, mod100 != 11 { return "\(self) задача" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "\(self) задачи" }
        return "\(self) задач"
    }
}
