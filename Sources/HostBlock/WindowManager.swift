import AppKit
import SwiftUI

/// Creates and reuses standalone NSWindows for the activation modal and the
/// license/custom-list panels — a menu bar app has no main window to anchor to.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    enum WindowID: String {
        case activation
        case licenseInfo
        case manageLists
    }

    private var windows: [WindowID: NSWindow] = [:]

    func showActivation() {
        show(.activation, title: "Activate HostBlock") { ActivationView() }
    }

    func showLicenseInfo() {
        show(.licenseInfo, title: "HostBlock License") { LicenseInfoView() }
    }

    func showManageLists() {
        show(.manageLists, title: "Custom Blocklists") { ManageListsView() }
    }

    func close(_ id: WindowID) {
        windows[id]?.close()
    }

    private func show<Content: View>(_ id: WindowID, title: String, @ViewBuilder content: () -> Content) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        windows[id] = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WindowManager.shared.windows[id] = nil
            }
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
