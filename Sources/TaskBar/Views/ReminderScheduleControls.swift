import SwiftUI

struct ReminderScheduleControls: View {
    @Binding var schedule: ReminderSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("как часто?")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Picker("", selection: $schedule.frequency) {
                    ForEach(ReminderFrequency.allCases) { item in
                        Text("\(item.title) · \(item.subtitle)").tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 220)
            }

            HStack(spacing: 8) {
                Text("окно")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Picker("с", selection: $schedule.startHour) {
                    ForEach(6..<23, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .labelsHidden()
                Text("–")
                    .foregroundStyle(Theme.muted)
                Picker("до", selection: $schedule.endHour) {
                    ForEach((schedule.startHour + 1)...24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .labelsHidden()
            }
        }
        .padding(.top, 2)
    }
}

struct TaskTextField<Content: View>: View {
    let placeholder: String
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.fieldFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.6)
            }
            .accessibilityLabel(placeholder)
    }
}

struct OptionalDefaultAction: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyboardShortcut(.defaultAction)
        } else {
            content
        }
    }
}
