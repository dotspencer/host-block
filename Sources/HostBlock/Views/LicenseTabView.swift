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
        .padding(16)
    }

    // MARK: Active license

    private func active(_ license: LicenseInfo) -> some View {
        VStack(spacing: 12) {
            licenseCard(license)
            if license.tier == .personal {
                upgradeCard
            }
            Button(action: { state.deactivate() }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Remove License")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.color(for: .malware))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.color(for: .malware).opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.color(for: .malware).opacity(0.3)))
            }
            .buttonStyle(.plain)
        }
    }

    private func licenseCard(_ license: LicenseInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "shield.fill").foregroundStyle(Theme.accent))
                Text("\(license.tier.displayName) License")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                StatusBadge(text: "ACTIVE", color: Theme.accent)
                Spacer()
            }

            HStack(spacing: 8) {
                Text("Licensed to")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text(license.email)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }

            HStack(spacing: 10) {
                infoBox(title: "Plan", value: "\(license.tier.displayName) — \(license.tier.deviceLimit.lowercased())")
                infoBox(title: "Devices", value: state.deviceUsage)
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.3)))
    }

    private func infoBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 8))
    }

    private var upgradeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(Theme.info)
                Text("Upgrade to Pro")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text("Use HostBlock on unlimited devices with a single Pro license.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: AppConstants.upgradeURL) {
                HStack(spacing: 6) {
                    Text("Upgrade to Pro")
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.info, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.info.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.info.opacity(0.25)))
    }

    // MARK: Activation

    private var activation: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surfaceElevated)
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: "key.fill").font(.system(size: 22)).foregroundStyle(Theme.textSecondary))
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("Activate HostBlock")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Enter your license key to activate")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            ActivationField()

            if let error = state.activationError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color(for: .malware))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            freeLicenseCard
        }
    }

    private var freeLicenseCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Free Personal License")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("HostBlock is free for personal use on 1 device. Get a free key at hostblock.app.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: AppConstants.freeLicenseURL) {
                HStack(spacing: 4) {
                    Text("Get free license")
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.info)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
    }
}

/// Isolated so its local text state doesn't re-render the whole License tab on each keystroke.
private struct ActivationField: View {
    @ObservedObject private var state = AppState.shared
    @State private var key = ""

    var body: some View {
        VStack(spacing: 10) {
            TextField("HSTBLK-XXXX-XXXX-XXXX", text: $key)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .onSubmit { state.activate(licenseKey: key) }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))

            Button(action: { state.activate(licenseKey: key) }) {
                Text(state.isActivating ? "Activating…" : "Activate License")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .disabled(state.isActivating)
        }
    }
}
