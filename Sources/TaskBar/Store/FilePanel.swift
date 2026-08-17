import AppKit
import UniformTypeIdentifiers

@MainActor
enum FilePanel {
    static func open(
        _ setup: (NSOpenPanel) -> Void,
        completion: @escaping (NSOpenPanel, Bool) -> Void
    ) {
        let panel = NSOpenPanel()
        setup(panel)
        present(panel) { response in
            completion(panel, response == .OK)
        }
    }

    static func save(
        _ setup: (NSSavePanel) -> Void,
        completion: @escaping (URL?) -> Void
    ) {
        let panel = NSSavePanel()
        setup(panel)
        present(panel) { response in
            completion(response == .OK ? panel.url : nil)
        }
    }

    private static func present(
        _ panel: NSSavePanel,
        completion: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        let host = PanelHost.shared
        host.begin(panel: panel, completion: completion)
    }
}

/// Menu-bar extras run as `.accessory` and their popover is a non-activating window.
/// NSOpenPanel shown from there appears, but clicks never reach it. Host the panel
/// from a regular, key window after temporarily becoming a normal app.
@MainActor
final class PanelHost {
    static let shared = PanelHost()

    private var hostWindow: NSWindow?
    private var completion: ((NSApplication.ModalResponse) -> Void)?

    func begin(panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        self.completion = completion

        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSApp.activate()

        panel.level = .modalPanel
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.center()

        let host = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        host.isReleasedWhenClosed = false
        host.alphaValue = 0
        host.level = .floating
        host.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        host.center()
        host.makeKeyAndOrderFront(nil)
        hostWindow = host

        DispatchQueue.main.async {
            panel.beginSheetModal(for: host) { [weak self] response in
                self?.finish(response)
            }
        }
    }

    private func finish(_ response: NSApplication.ModalResponse) {
        let callback = completion
        completion = nil
        hostWindow?.orderOut(nil)
        hostWindow = nil
        NSApp.setActivationPolicy(.accessory)
        callback?(response)
    }
}
