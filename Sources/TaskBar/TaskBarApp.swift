import AppKit
import SwiftUI
import UserNotifications

@main
struct TaskBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = TaskStore()
    @State private var settings = AppSettings()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(store)
                .environment(settings)
                .environment(\.colorScheme, settings.appearance.colorScheme)
                .preferredColorScheme(settings.appearance.colorScheme)
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
        AppearanceBridge.markReady()
        let stored = UserDefaults.standard.string(forKey: "TaskBar.appearance") ?? ""
        AppearanceBridge.apply(ColorSchemeChoice(rawValue: stored) ?? .dark)
    }
}
