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
        AppState.shared.bootstrap()
    }
}
