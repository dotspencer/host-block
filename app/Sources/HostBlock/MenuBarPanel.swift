import AppKit

/// Opens the MenuBarExtra dropdown, which SwiftUI gives no API to present. Reaches
/// the NSStatusItem it creates and clicks the button. Fails soft: if a future macOS
/// stops exposing it, the dropdown just doesn't auto-open.
@MainActor
enum MenuBarPanel {
    /// Not KVC: `value(forKey:)` on an unknown key raises an uncatchable ObjC exception.
    private static let statusItemSelector = Selector(("statusItem"))

    private static var statusItem: NSStatusItem? {
        guard
            let window = NSApp.windows.first(where: { $0.className == "NSStatusBarWindow" }),
            window.responds(to: statusItemSelector),
            let item = window.perform(statusItemSelector)?.takeUnretainedValue() as? NSStatusItem
        else { return nil }
        return item
    }

    /// False until the status item is usable, or forever on a macOS that hides it.
    @discardableResult
    static func open() -> Bool {
        guard
            let button = statusItem?.button,
            // The dropdown is anchored to the button, which briefly has no menu bar
            // slot: first empty at the origin, then sized but offscreen. Clicking
            // during either opens the panel offscreen too. isEmpty isn't redundant,
            // intersects returns true for a zero-height rect at the origin.
            let slot = button.window?.frame,
            let screen = NSScreen.main?.frame,
            !slot.isEmpty,
            screen.intersects(slot)
        else { return false }

        // The panel closes as soon as it isn't key, and an .accessory app isn't active
        // on launch, so without this it is built and torn down in one breath.
        NSApp.activate(ignoringOtherApps: true)
        button.performClick(nil)
        return true
    }

    /// Dismisses the dropdown. It outlives losing key, above ordinary window levels, so
    /// anything opened from inside it comes up underneath.
    static func close() {
        guard let button = statusItem?.button, button.state == .on else { return }
        button.performClick(nil)
    }

    /// Polls for the status item rather than racing it. Gives up after ~3s.
    static func openWhenReady(attemptsRemaining: Int = 30) {
        guard attemptsRemaining > 0 else { return }
        if open() { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            openWhenReady(attemptsRemaining: attemptsRemaining - 1)
        }
    }
}
