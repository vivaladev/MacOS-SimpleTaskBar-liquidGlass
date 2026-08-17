import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PanelView: View {
    @Environment(TaskStore.self) private var store
    @Environment(AppSettings.self) private var settings

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
        .id(settings.appearance)
        .environment(\.colorScheme, settings.appearance.colorScheme)
        .preferredColorScheme(settings.appearance.colorScheme)
        .containerBackground(for: .window) {
            Rectangle().fill(.regularMaterial)
        }
        .onPasteCommand(of: [.image, .fileURL, .png, .jpeg, .tiff]) { _ in
            store.ingestPastedImages()
        }
        .onAppear {
            AppearanceBridge.apply(settings.appearance)
            ImagePasteHandler.shared.start(onPaste: { store.ingestPastedImages() })
        }
        .onChange(of: settings.appearance) { _, newValue in
            AppearanceBridge.apply(newValue)
        }
        .onDisappear { ImagePasteHandler.shared.stop() }
        .task {
            await store.bootstrap()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Задачи")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        Button {
                            settings.toggleAppearance()
                        } label: {
                            Image(systemName: settings.appearance.icon)
                        }
                        .help(settings.appearance == .dark ? "Светлая тема" : "Тёмная тема")

                        Menu {
                            Button("Экспорт…") { store.exportBackup() }
                            Button("Импорт…") { store.importBackup() }
                        } label: {
                            Image(systemName: "square.and.arrow.up.on.square")
                        }
                        .help("Импорт и экспорт")

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
                        TaskCardView(item: item, hovered: store.hoveredTaskID == item.id)
                            .onHover { hovering in
                                if hovering {
                                    store.hoveredTaskID = item.id
                                } else if store.hoveredTaskID == item.id {
                                    store.hoveredTaskID = nil
                                }
                            }
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
            if let toast = store.toast {
                Text(toast)
                    .foregroundStyle(Theme.accent)
            } else if !store.notificationsAllowed, store.tasks.contains(where: \.remind) {
                Text("Уведомления выключены в системе")
                    .foregroundStyle(Theme.overdue)
            } else {
                Text(footerSummary)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("v1.2.0")
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

@MainActor
final class ImagePasteHandler {
    static let shared = ImagePasteHandler()

    private var monitor: Any?
    private var onPaste: () -> Void = {}

    func start(onPaste: @escaping () -> Void) {
        stop()
        self.onPaste = onPaste
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let command = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
            guard command, event.charactersIgnoringModifiers == "v" else { return event }
            let hasText = !(NSPasteboard.general.string(forType: .string)?.isEmpty ?? true)
            let images = ImageCodec.jpegData(from: .general)
            if !images.isEmpty, !hasText {
                Task { @MainActor in
                    ImagePasteHandler.shared.onPaste()
                }
                return nil
            }
            return event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        onPaste = {}
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
