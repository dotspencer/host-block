import HostBlockCore
import SwiftUI

struct ActivationView: View {
    @ObservedObject private var state = AppState.shared
    @State private var key = ""

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Activate HostBlock")
                .font(.title2.bold())
            Text("Paste the license key from your Gumroad purchase email.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            TextField("XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX", text: $key)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .onSubmit { state.activate(licenseKey: key) }

            if let error = state.activationError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Link("Get a license", destination: AppConstants.purchaseURL)
                    .font(.callout)
                Spacer()
                Button {
                    state.activate(licenseKey: key)
                } label: {
                    Text(state.isActivating ? "Activating…" : "Activate")
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(state.isActivating)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
