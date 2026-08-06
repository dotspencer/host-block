import AppKit
import SwiftUI

@main
struct HostBlockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var state = AppState.shared

    private var menuBarIcon: String {
        if state.license == nil || !state.helperInstalled || !state.protectionEnabled {
            return "shield.slash"
        }
        return "shield.fill"
    }

    var body: some Scene {
        MenuBarExtra("HostBlock", systemImage: menuBarIcon) {
            MenuView()
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar app: no Dock icon, even when run outside a bundle (swift run).
        NSApp.setActivationPolicy(.accessory)
        // The dropdown commits to a dark look; force dark app appearance so the menu
        // window's own chrome (its rounded border) is drawn dark too, instead of the
        // bright light ring that appears when the system is in light mode.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        AppState.shared.bootstrap()

        // With no Dock icon or window, a launch is invisible: two users reported
        // "crashing" when they had just missed the shield. Only while setup is
        // unfinished, so launch-at-login doesn't pop a panel every boot.
        if AppState.shared.needsSetup {
            MenuBarPanel.openWhenReady()
        }
    }
}
