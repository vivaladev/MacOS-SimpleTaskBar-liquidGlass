import SwiftUI

struct TaskCardView: View {
    @Environment(TaskStore.self) private var store
    let item: TaskItem

    @State private var hovering = false

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

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Button {
                        store.delete(item)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.mini)
                    .opacity(hovering ? 1 : 0.35)
                    .help("Удалить")
                }

                Text(item.notes.isEmpty ? "без описания" : item.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(item.notes.isEmpty ? Theme.muted.opacity(0.8) : Color.white.opacity(0.78))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Text(deadlineText)
                        .foregroundStyle(overdue ? Theme.overdue : Theme.muted)

                    HStack(spacing: 4) {
                        Image(systemName: item.remind ? "bell.fill" : "bell.slash")
                        Text(item.remind ? "напоминать" : "не напоминать")
                    }
                    .foregroundStyle(item.remind ? accent.opacity(0.95) : Theme.muted)
                }
                .font(.system(size: 11, weight: .medium))
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(overdue ? Theme.overdue.opacity(0.10) : Color.white.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(overdue ? Theme.overdue.opacity(0.45) : Theme.hairline, lineWidth: 0.8)
        }
        .glassEffect(
            overdue ? .regular.tint(Theme.overdue.opacity(0.35)) : .regular,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .onHover { hovering = $0 }
        .contextMenu {
            Button(item.remind ? "Не напоминать" : "Напоминать") {
                store.toggleRemind(item)
            }
            Button("Удалить", role: .destructive) {
                store.delete(item)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
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
}
