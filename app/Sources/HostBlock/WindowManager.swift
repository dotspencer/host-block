import AppKit
import SwiftUI

/// Owns the standalone Preferences window. Everything else (activation, license
/// details, custom lists) now lives inline in the dropdown's tabs.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var preferences: NSWindow?

    func showPreferences() {
        if let existing = preferences {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView()))
        window.title = "HostBlock Preferences"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        preferences = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor in WindowManager.shared.preferences = nil }
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
