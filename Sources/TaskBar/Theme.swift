import AppKit
import SwiftUI

enum ColorSchemeChoice: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        self == .light ? .light : .dark
    }

    var nsAppearance: NSAppearance? {
        NSAppearance(named: self == .light ? .aqua : .darkAqua)
    }

    var icon: String {
        self == .light ? "sun.max.fill" : "moon.fill"
    }

    var title: String {
        self == .light ? "Светлая" : "Тёмная"
    }

    var toggled: ColorSchemeChoice {
        self == .light ? .dark : .light
    }
}

enum Theme {
    static let accent = Color(red: 1.0, green: 0.478, blue: 0.102)
    static let overdue = Color(red: 0.93, green: 0.26, blue: 0.26)
    static let dueToday = Color(red: 0.95, green: 0.62, blue: 0.12)
    static let muted = Color.primary.opacity(0.55)
    static let hairline = Color.primary.opacity(0.14)
    static let cardFill = Color.primary.opacity(0.05)
    static let fieldFill = Color.primary.opacity(0.06)
    static let panelWidth: CGFloat = 408
    static let panelHeight: CGFloat = 760
}

@MainActor
enum AppearanceBridge {
    private static var isReady = false

    static func markReady() {
        isReady = true
    }

    static func apply(_ choice: ColorSchemeChoice) {
        guard isReady else { return }
        let app = NSApplication.shared
        let appearance = choice.nsAppearance
        app.appearance = appearance
        for window in app.windows {
            window.appearance = appearance
            window.contentView?.appearance = appearance
        }
    }
}
