import HostBlockCore
import SwiftUI

struct LicenseTabView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        Group {
            if let license = state.license {
                active(license)
            } else {
                activation
            }
        }
        .padding(14)
    }

    // MARK: Active license

    private func active(_ license: LicenseInfo) -> some View {
        VStack(spacing: 11) {
            licenseCard(license)
            if let error = state.deactivationError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if license.tier == .personal {
                upgradeCard
            }
        }
    }

    private func licenseCard(_ license: LicenseInfo) -> some View {
        VStack(spacing: 0) {
            // Title: tier + device limit (e.g. "Personal · 1 device").
            HStack(spacing: 5) {
                Text(license.tier.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("· \(license.tier.deviceLimit)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            rowDivider
            infoRow(label: "Email", value: license.email)
            rowDivider
            infoRow(label: "Purchased", value: purchasedText(license))
            rowDivider
            infoRow(label: "Payment", value: paymentText(license))
            rowDivider
            removeRow
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.stroke))
    }

    private var rowDivider: some View {
        Rectangle().fill(Theme.separator).frame(height: 1)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 11) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 7)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var removeRow: some View {
        Button(action: { state.deactivate() }) {
            HStack(spacing: 7) {
                if state.isDeactivating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "trash")
                }
                Text(state.isDeactivating ? "Releasing device…" : "Remove license")
                Spacer()
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state.isDeactivating)
    }

    private func purchasedText(_ license: LicenseInfo) -> String {
        guard let date = license.purchaseDate else { return "—" }
        return Self.dateFormatter.string(from: date)
    }

    /// Builds "Visa •••• 4821" from Gumroad's card type + masked visual. Falls back
    /// gracefully when either piece is missing.
    private func paymentText(_ license: LicenseInfo) -> String {
        let last4 = (license.cardVisual ?? "").filter(\.isNumber).suffix(4)
        let type = license.cardType?.capitalized
        switch (type, last4.isEmpty) {
        case let (type?, false): return "\(type) •••• \(last4)"
        case let (type?, true): return type
        case (nil, false): return "•••• \(last4)"
        default: return "—"
        }
    }

    private var upgradeCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "info.circle").foregroundStyle(Theme.info)
                Text("Upgrade to Pro")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text("Use HostBlock on unlimited devices with a single Pro license.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: AppConstants.upgradeURL) {
                HStack(spacing: 5) {
                    Text("Upgrade to Pro")
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.info, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.info.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.info.opacity(0.25)))
    }

    // MARK: Activation

    private var activation: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11)
                .fill(Theme.surfaceElevated)
                .frame(width: 49, height: 49)
                .overlay(Image(systemName: "key.fill").font(.system(size: 18)).foregroundStyle(Theme.textSecondary))
                .padding(.top, 7)

            VStack(spacing: 4) {
                Text("Activate HostBlock")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Enter your license key to activate")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }

            ActivationField()

            if let error = state.activationError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            freeLicenseCard
        }
    }

    private var freeLicenseCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Free Personal License")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("HostBlock is free for personal use on 1 device. Get a free key at hostblock.app.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: AppConstants.freeLicenseURL) {
                HStack(spacing: 4) {
                    Text("Get free license")
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.info)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.stroke))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        // Format in UTC so the shown calendar day matches Gumroad's sale date and
        // doesn't roll back a day for viewers in timezones behind UTC.
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

/// Isolated so its local text state doesn't re-render the whole License tab on each keystroke.
private struct ActivationField: View {
    @ObservedObject private var state = AppState.shared
    @State private var key = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 9) {
            TextField("XXXX-XXXX-XXXX-XXXX", text: $key)
                .textFieldStyle(.plain)
                .tint(.white)
                .focused($isInputFocused)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .onSubmit { state.activate(licenseKey: key) }
                // Keep the field single-line and clean: a pasted key often carries a
                // trailing newline/space (e.g. copied from an email), which otherwise
                // grows the field and scrolls the text out of view.
                .onChange(of: key) { newValue in
                    let cleaned = newValue.components(separatedBy: .newlines).joined()
                        .trimmingCharacters(in: .whitespaces)
                    if cleaned != newValue { key = cleaned }
                }
                .padding(11)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.stroke))
                // .defaultFocus (the declarative way) silently fails inside a
                // MenuBarExtra popover — the window isn't key when it's evaluated.
                // Setting focus a beat after appear is the reliable workaround here.
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInputFocused = true
                    }
                }

            Button(action: { state.activate(licenseKey: key) }) {
                Text(state.isActivating ? "Activating…" : "Activate License")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Theme.accent.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.accent.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .disabled(state.isActivating)
        }
    }
}
