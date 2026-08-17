import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TaskCardView: View {
    @Environment(TaskStore.self) private var store
    let item: TaskItem
    var hovered: Bool = false

    @State private var title = ""
    @State private var notes = ""
    @State private var deadline = Date()
    @State private var remind = true
    @State private var isDaily = false
    @State private var schedule = ReminderSchedule.default
    @FocusState private var titleFocused: Bool

    private var isEditing: Bool { store.editingTaskID == item.id }
    private var overdue: Bool { item.isOverdue() }
    private var dueToday: Bool { item.isDueToday() }
    private var accent: Color {
        if overdue { return Theme.overdue }
        if dueToday { return Theme.dueToday }
        return Theme.accent
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Capsule()
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    editor
                } else {
                    readout
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(overdue ? Theme.overdue.opacity(0.10) : Theme.cardFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isEditing ? Theme.accent.opacity(0.55) : (overdue ? Theme.overdue.opacity(0.45) : Theme.hairline),
                    lineWidth: isEditing ? 1.2 : 0.8
                )
        }
        .glassEffect(
            overdue ? .regular.tint(Theme.overdue.opacity(0.35)) : .regular,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .onTapGesture(count: 2) {
            startEditing()
        }
        .onChange(of: isEditing) { _, editing in
            if editing { loadDraft() }
        }
        .onExitCommand {
            if isEditing { store.cancelEditing() }
        }
        .contextMenu {
            Button("Редактировать") { startEditing() }
            Button(item.remind ? "Не напоминать" : "Напоминать") {
                store.toggleRemind(item)
            }
            Button("Прикрепить картинку") {
                addPickedImages()
            }
            Button("Удалить", role: .destructive) {
                store.delete(item)
            }
        }
        .accessibilityElement(children: isEditing ? .contain : .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Button {
                    startEditing()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.mini)
                .opacity(hovered ? 1 : 0.4)
                .help("Редактировать")

                Button {
                    store.delete(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.mini)
                .opacity(hovered ? 1 : 0.35)
                .help("Удалить")
            }

            Text(item.notes.isEmpty ? "без описания" : item.notes)
                .font(.system(size: 12))
                .foregroundStyle(item.notes.isEmpty ? Theme.muted.opacity(0.8) : Color.primary.opacity(0.78))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            imageStrip

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(deadlineText)
                        .foregroundStyle(overdue ? Theme.overdue : Theme.muted)

                    HStack(spacing: 4) {
                        Image(systemName: item.remind ? "bell.fill" : "bell.slash")
                        Text(item.remind ? item.schedule.frequency.title.lowercased() : "не напоминать")
                    }
                    .foregroundStyle(item.remind ? accent.opacity(0.95) : Theme.muted)
                }

                if item.remind {
                    Text(item.schedule.summary)
                        .foregroundStyle(Theme.muted)
                }
            }
            .font(.system(size: 11, weight: .medium))
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Редактирование")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .textCase(.uppercase)
                    .tracking(0.3)
                Spacer()
                Button {
                    store.delete(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.mini)
                .help("Удалить")
            }

            TaskTextField(placeholder: "название") {
                TextField("", text: $title, prompt: Text("название").foregroundStyle(Theme.muted))
                    .textFieldStyle(.plain)
                    .focused($titleFocused)
                    .onSubmit(save)
            }

            TaskTextField(placeholder: "текст") {
                TextField("", text: $notes, prompt: Text("текст").foregroundStyle(Theme.muted), axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
            }

            imageStrip

            Picker("тип", selection: $isDaily) {
                Text("разово").tag(false)
                Text("каждый день").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isDaily ? "повтор" : "до когда?")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.muted)
                    if isDaily {
                        Text("каждый день")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.vertical, 4)
                    } else {
                        DatePicker("", selection: $deadline, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("нужно напомнить?")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.muted)
                    Toggle("", isOn: $remind)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .tint(Theme.accent)
                        .controlSize(.small)
                }
            }

            if remind {
                ReminderScheduleControls(schedule: $schedule)
            }

            HStack(spacing: 8) {
                Button("Отмена") {
                    store.cancelEditing()
                }
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)

                Button("Сохранить") {
                    save()
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var imageStrip: some View {
        ImageStripView(
            images: item.attachments.compactMap { AttachmentStore.shared.image(for: $0, taskID: item.id) },
            onRemove: { index in
                guard item.attachments.indices.contains(index) else { return }
                store.removeAttachment(item.attachments[index], from: item.id)
            },
            onAdd: { addPickedImages() },
            onOpen: { index in
                guard item.attachments.indices.contains(index) else { return }
                let url = AttachmentStore.shared.url(for: item.attachments[index], taskID: item.id)
                NSWorkspace.shared.open(url)
            }
        )
    }

    private var deadlineText: String {
        if item.isDaily {
            return "каждый день"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        let date = formatter.string(from: item.deadline)
        if overdue {
            return "просрочено · до \(date)"
        }
        if dueToday {
            return "сегодня · до \(date)"
        }
        return "до \(date)"
    }

    private var accessibilityText: String {
        "\(item.title), \(deadlineText)"
    }

    private func startEditing() {
        loadDraft()
        store.beginEditing(item)
        titleFocused = true
    }

    private func loadDraft() {
        title = item.title
        notes = item.notes
        deadline = item.deadline
        remind = item.remind
        isDaily = item.isDaily
        schedule = item.schedule
    }

    private func save() {
        store.update(
            id: item.id,
            title: title,
            notes: notes,
            deadline: deadline,
            remind: remind,
            isDaily: isDaily,
            schedule: schedule
        )
    }

    private func addPickedImages() {
        ImagePicker.pick { addImages($0) }
    }

    private func addImages(_ incoming: [Data]) {
        for jpeg in incoming {
            _ = store.addImage(jpeg, to: item.id)
        }
    }
}
