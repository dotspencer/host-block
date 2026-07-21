import HostBlockCore
import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Toggle(isOn: Binding(
                get: { AppState.shared.launchAtLogin },
                set: { AppState.shared.setLaunchAtLogin($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login").foregroundStyle(Theme.textPrimary)
                    Text("Start HostBlock automatically when you sign in.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .toggleStyle(GreenToggleStyle())

            Divider().overlay(Theme.separator)

            HStack(spacing: 10) {
                Image(systemName: state.helperInstalled ? "checkmark.shield.fill" : "exclamationmark.shield")
                    .foregroundStyle(state.helperInstalled ? Theme.accent : Theme.color(for: .ads))
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.helperInstalled ? "Helper installed" : "Setup required")
                        .foregroundStyle(Theme.textPrimary)
                    Text(state.helperInstalled
                         ? "HostBlock can update the hosts file without prompting."
                         : "Grant admin access once to enable blocking.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if !state.helperInstalled {
                    Button("Finish Setup…") { state.finishSetup() }
                }
            }

            Divider().overlay(Theme.separator)

            Button {
                state.flushDNS()
            } label: {
                Label("Flush DNS Cache", systemImage: "wind")
            }
            .disabled(!state.helperInstalled || state.isWorking)

            Spacer()
        }
        .padding(20)
        .frame(width: 380, height: 300)
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
    }
}
