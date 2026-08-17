import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @Environment(TaskStore.self) private var store
    @Binding var isExpanded: Bool

    @State private var title = ""
    @State private var notes = ""
    @State private var deadline = Date()
    @State private var remind = true
    @State private var isDaily = false
    @State private var schedule = ReminderSchedule.default
    @FocusState private var titleFocused: Bool

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if isExpanded {
                expandedForm
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                collapsedBar
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.22), value: isExpanded)
        .onChange(of: isExpanded) { _, open in
            if open {
                DispatchQueue.main.async {
                    titleFocused = true
                }
            }
        }
    }

    private var collapsedButton: some View {
        Button {
            isExpanded = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Новая задача")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.accent)
        .help("Создать задачу")
        .keyboardShortcut("n", modifiers: .command)
    }

    private var collapsedBar: some View {
        HStack {
            Spacer(minLength: 0)
            collapsedButton
            Spacer(minLength: 0)
        }
    }

    private var expandedForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Создать новое")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.mini)
                .help("Скрыть")
                .keyboardShortcut(.cancelAction)
            }

            TaskTextField(placeholder: "название") {
                TextField("", text: $title, prompt: Text("название").foregroundStyle(Theme.muted))
                    .textFieldStyle(.plain)
                    .focused($titleFocused)
                    .onSubmit(submit)
            }

            TaskTextField(placeholder: "текст") {
                TextField("", text: $notes, prompt: Text("текст").foregroundStyle(Theme.muted), axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...3)
            }

            ImageStripView(
                images: ImagePicker.nsImages(from: store.composerImages),
                onRemove: { index in
                    guard store.composerImages.indices.contains(index) else { return }
                    store.composerImages.remove(at: index)
                },
                onAdd: { ImagePicker.pick { appendImages($0) } }
            )

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

            Button(action: submit) {
                Text("Добавить")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            .disabled(!canSubmit)
            .modifier(OptionalDefaultAction(enabled: store.editingTaskID == nil))
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func appendImages(_ incoming: [Data]) {
        for jpeg in incoming {
            guard store.composerImages.count < ImageCodec.maxAttachments else { break }
            store.composerImages.append(jpeg)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        store.add(
            title: title,
            notes: notes,
            deadline: deadline,
            remind: remind,
            isDaily: isDaily,
            schedule: schedule,
            images: store.composerImages
        )
        title = ""
        notes = ""
        deadline = Date()
        remind = true
        isDaily = false
        schedule = .default
        isExpanded = false
    }
}
