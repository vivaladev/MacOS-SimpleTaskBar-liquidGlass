import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {
    nonisolated private static let appearanceKey = "TaskBar.appearance"

    var appearance: ColorSchemeChoice {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
            AppearanceBridge.apply(appearance)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.appearanceKey) ?? ""
        appearance = ColorSchemeChoice(rawValue: stored) ?? .dark
        Self.observeWindows()
    }

    func toggleAppearance() {
        appearance = appearance.toggled
    }

    private static func observeWindows() {
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didExposeNotification,
        ]
        for name in names {
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    let stored = UserDefaults.standard.string(forKey: AppSettings.appearanceKey) ?? ""
                    AppearanceBridge.apply(ColorSchemeChoice(rawValue: stored) ?? .dark)
                }
            }
        }
    }
}
