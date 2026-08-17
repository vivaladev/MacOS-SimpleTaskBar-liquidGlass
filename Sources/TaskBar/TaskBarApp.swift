import AppKit
import SwiftUI
import UserNotifications

@main
struct TaskBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = TaskStore()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(store)
                .preferredColorScheme(.dark)
        } label: {
            MenuBarLabel(overdueCount: store.overdueCount)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let overdueCount: Int

    var body: some View {
        Image(systemName: overdueCount > 0 ? "exclamationmark.circle.fill" : "checkmark.circle")
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel(overdueCount > 0 ? "Задачи, просрочено \(overdueCount)" : "Задачи")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ReminderService.shared.configure()
    }
}
