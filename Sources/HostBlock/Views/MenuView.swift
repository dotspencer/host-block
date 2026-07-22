import AppKit
import HostBlockCore
import SwiftUI

struct MenuView: View {
    @ObservedObject private var state = AppState.shared

    private var isActive: Bool {
        state.license != nil && state.protectionEnabled && state.helperInstalled
    }

    var body: some View {
        VStack(spacing: s(0)) {
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
        HStack(spacing: s(12)) {
            RoundedRectangle(cornerRadius: s(10))
                .fill(isActive ? Theme.accent.opacity(0.18) : Theme.surfaceElevated)
                .frame(width: s(44), height: s(44))
                .overlay(
                    Image(systemName: isActive ? "shield.fill" : "shield.slash")
                        .font(.system(size: s(20)))
                        .foregroundStyle(isActive ? Theme.accent : Theme.textSecondary)
                )

            VStack(alignment: .leading, spacing: s(3)) {
                HStack(spacing: s(8)) {
                    Text("HostBlock")
                        .font(.system(size: s(16), weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if state.license != nil {
                        StatusBadge(
                            text: state.protectionEnabled ? "ACTIVE" : "PAUSED",
                            color: state.protectionEnabled ? Theme.accent : Theme.textSecondary
                        )
                    }
                }
                Text(subline)
                    .font(.system(size: s(12), design: .monospaced))
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
        .padding(s(16))
    }

    private var subline: String {
        guard state.license != nil else { return "Not activated" }
        if !state.protectionEnabled || !state.helperInstalled { return "Blocking disabled" }
        return "\(Theme.abbreviate(state.blockedCount)) domains blocked"
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: s(0)) {
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
            VStack(spacing: s(0)) {
                HStack(spacing: s(6)) {
                    Image(systemName: locked ? "lock.fill" : tab.icon)
                        .font(.system(size: s(12), weight: .medium))
                    Text(tab.title)
                        .font(.system(size: s(13), weight: selected ? .semibold : .regular))
                }
                .foregroundStyle(selected ? Theme.textPrimary : (locked ? Theme.textTertiary : Theme.textSecondary))
                .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(selected ? Theme.accent : .clear)
                    .frame(height: s(2))
            }
            // Full-width, full-height cell with a solid hit shape so a click anywhere
            // in the tab column — including the space above and below the label — selects it.
            .frame(maxWidth: .infinity, minHeight: s(48))
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
                .font(.system(size: s(12), design: .monospaced))
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
        .font(.system(size: s(13)))
        .padding(s(16))
    }
}
