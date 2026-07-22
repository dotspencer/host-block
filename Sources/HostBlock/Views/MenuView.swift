import AppKit
import HostBlockCore
import SwiftUI

struct MenuView: View {
    @ObservedObject private var state = AppState.shared

    private var isActive: Bool {
        state.license != nil && state.protectionEnabled && state.helperInstalled
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
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 9)
                .fill(isActive ? Theme.accent.opacity(0.18) : Theme.surfaceElevated)
                .frame(width: 39, height: 39)
                .overlay(
                    Image(systemName: isActive ? "shield.fill" : "shield.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(isActive ? Theme.accent : Theme.textSecondary)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("HostBlock")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if state.license != nil {
                        StatusBadge(
                            text: state.protectionEnabled ? "ACTIVE" : "PAUSED",
                            color: state.protectionEnabled ? Theme.accent : Theme.textSecondary
                        )
                    }
                }
                Text(subline)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { AppState.shared.protectionEnabled },
                set: { AppState.shared.setProtection($0) }
            ))
            .labelsHidden()
            .toggleStyle(GreenToggleStyle())
            .disabled(state.license == nil)
            .opacity(state.license == nil ? 0.4 : 1)
        }
        .padding(14)
    }

    private var subline: String {
        guard state.license != nil else { return "Not activated" }
        if !state.protectionEnabled || !state.helperInstalled { return "Blocking disabled" }
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
                        .font(.system(size: 11, weight: .medium))
                    Text(tab.title)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                }
                .foregroundStyle(selected ? Theme.textPrimary : (locked ? Theme.textTertiary : Theme.textSecondary))
                .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(selected ? Theme.accent : .clear)
                    .frame(height: 2)
            }
            // Full-width, full-height cell with a solid hit shape so a click anywhere
            // in the tab column — including the space above and below the label — selects it.
            .frame(maxWidth: .infinity, minHeight: 42)
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
        case .browse: BrowseTabView()
        case .license: LicenseTabView()
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text("v\(AppConstants.appVersion)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Button("Preferences") { WindowManager.shared.showPreferences() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
            Text("·").foregroundStyle(Theme.textTertiary)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
        }
        .font(.system(size: 11))
        .padding(14)
    }
}
