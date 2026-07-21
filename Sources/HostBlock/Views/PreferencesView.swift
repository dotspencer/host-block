import HostBlockCore
import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: s(16)) {
            Text("Preferences")
                .font(.system(size: s(17), weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            // GreenToggleStyle renders only the pill, so the label goes beside it here.
            HStack(alignment: .center, spacing: s(12)) {
                VStack(alignment: .leading, spacing: s(2)) {
                    Text("Launch at login").foregroundStyle(Theme.textPrimary)
                    Text("Start HostBlock automatically when you sign in.")
                        .font(.system(size: s(12)))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { AppState.shared.launchAtLogin },
                    set: { AppState.shared.setLaunchAtLogin($0) }
                ))
                .labelsHidden()
                .toggleStyle(GreenToggleStyle())
            }

            Divider().overlay(Theme.separator)

            HStack(spacing: s(10)) {
                Image(systemName: state.helperInstalled ? "checkmark.shield.fill" : "exclamationmark.shield")
                    .foregroundStyle(state.helperInstalled ? Theme.accent : Theme.color(for: .ads))
                VStack(alignment: .leading, spacing: s(2)) {
                    Text(state.helperInstalled ? "Helper installed" : "Setup required")
                        .foregroundStyle(Theme.textPrimary)
                    Text(state.helperInstalled
                         ? "HostBlock can update the hosts file without prompting."
                         : "Grant admin access once to enable blocking.")
                        .font(.system(size: s(12)))
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
        .padding(s(20))
        .frame(width: s(380), height: s(300))
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
    }
}
