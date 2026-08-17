import SwiftUI

struct ComposerView: View {
    @Environment(TaskStore.self) private var store

    @State private var title = ""
    @State private var notes = ""
    @State private var deadline = Date()
    @State private var remind = true
    @State private var isDaily = false
    @FocusState private var titleFocused: Bool

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Создать новое")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .textCase(.uppercase)
                .tracking(0.4)

            field(placeholder: "название") {
                TextField("", text: $title, prompt: Text("название").foregroundStyle(Theme.muted))
                    .textFieldStyle(.plain)
                    .focused($titleFocused)
                    .onSubmit(submit)
            }

            field(placeholder: "текст") {
                TextField("", text: $notes, prompt: Text("текст").foregroundStyle(Theme.muted), axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
            }

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
                            .colorScheme(.dark)
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

            Button(action: submit) {
                Text("Добавить")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            .disabled(!canSubmit)
            .keyboardShortcut(.defaultAction)
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func field<Content: View>(placeholder: String, @ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.6)
            }
            .accessibilityLabel(placeholder)
    }

    private func submit() {
        guard canSubmit else { return }
        store.add(title: title, notes: notes, deadline: deadline, remind: remind, isDaily: isDaily)
        title = ""
        notes = ""
        deadline = Date()
        remind = true
        isDaily = false
        titleFocused = true
    }
}
