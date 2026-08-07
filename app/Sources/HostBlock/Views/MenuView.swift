import AppKit
import HostBlockCore
import SwiftUI

struct MenuView: View {
    @ObservedObject private var state = AppState.shared

    private var isActive: Bool {
        state.license != nil && state.isProtectionActive
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.separator)
            tabBar
            Divider().overlay(Theme.separator)
            tabContent
            Divider().overlay(Theme.separator)
            footer
        }
        .frame(width: Theme.panelWidth)
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
        // On each open, refresh the update check and the catalog so the footer and the
        // Lists tab reflect the latest without waiting for the hourly timer.
        .onAppear {
            state.checkForUpdatesOnDemand()
            state.refreshCatalogOnDemand()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 9)
                .fill(isActive ? Theme.accent.opacity(0.18) : Theme.surfaceElevated)
                .frame(width: 39, height: 39)
                .overlay(
                    Image(systemName: isActive ? "shield.fill" : "shield.slash")
                        .font(Theme.font(18))
                        .foregroundStyle(isActive ? Theme.accent : Theme.textSecondary)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("HostBlock")
                        .font(Theme.font(13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if state.license != nil {
                        StatusBadge(
                            text: state.isProtectionActive ? "ACTIVE" : "PAUSED",
                            color: state.isProtectionActive ? Theme.accent : Theme.textSecondary
                        )
                    }
                }
                Text(subline)
                    .font(Theme.font(11, mono: sublineIsMono))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { AppState.shared.isProtectionActive },
                set: { AppState.shared.setProtection($0) }
            ))
            .labelsHidden()
            .toggleStyle(GreenToggleStyle())
            .disabled(state.license == nil)
            .opacity(state.license == nil ? 0.4 : 1)
        }
        .padding(14)
    }

    /// The setup line is prose, not a stat readout, and doesn't fit the panel in mono.
    private var sublineIsMono: Bool { state.license == nil || state.helperInstalled }

    private var subline: String {
        guard state.license != nil else { return "Not activated" }
        // The one disabled state the user can act on, and declining the prompt is
        // otherwise silent, so point at Preferences instead of just reporting it.
        if !state.helperInstalled { return "Setup required" }
        if !state.protectionEnabled { return "Blocking disabled" }
        return "\(Theme.abbreviate(state.blockedCount)) domains blocked"
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: Tab) -> some View {
        let locked = tab.requiresLicense && state.license == nil
        let selected = state.selectedTab == tab
        return Button {
            if !locked { state.selectedTab = tab }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: locked ? "lock.fill" : tab.icon)
                        .font(Theme.font(11, weight: .medium))
                    Text(tab.title)
                        .font(Theme.font(12, weight: selected ? .semibold : .regular))
                }
                .foregroundStyle(selected ? Theme.textPrimary : (locked ? Theme.textTertiary : Theme.textSecondary))
                .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(selected ? Theme.accent : .clear)
                    .frame(height: 2)
            }
            // Full-width, fixed-height cell with a solid hit shape so a click anywhere
            // in the tab column, including the space above and below the label, selects
            // it. A fixed height (vs a min) keeps the bar from stretching to absorb extra
            // window height on shorter tabs.
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    // MARK: Content

    @ViewBuilder
    private var tabContent: some View {
        switch state.selectedTab {
        case .lists: ListsTabView()
        case .license: LicenseTabView()
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text("v\(AppConstants.appVersion)")
                .font(Theme.font(11, mono: true))
                .foregroundStyle(Theme.textTertiary)
            if let update = state.availableUpdate, let url = URL(string: update.url) {
                Button {
                    NSWorkspace.shared.open(url)
                    // Quit so the downloaded DMG can replace the running app. Blocking
                    // persists via /etc/hosts, so quitting doesn't unblock anything. The
                    // brief delay lets the browser launch before we terminate.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        NSApp.terminate(nil)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Update to v\(update.version)")
                    }
                    .font(Theme.font(11, weight: .medium))
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .help("Download HostBlock \(update.version)")
            }
            Spacer()
            Button("Preferences") { WindowManager.shared.showPreferences() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
            Text("·").foregroundStyle(Theme.textTertiary)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
        }
        .font(Theme.font(11))
        .padding(14)
    }
}
