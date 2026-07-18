import AppKit
import HostBlockCore
import SwiftUI

struct MenuView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        Group {
            if state.license == nil {
                unlicensedBody
            } else {
                licensedBody
            }
        }
        .frame(width: 320)
    }

    // MARK: Unlicensed

    private var unlicensedBody: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("HostBlock isn't activated")
                .font(.headline)
            Text("Enter your license key to start blocking.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Activate License…") { WindowManager.shared.showActivation() }
                .keyboardShortcut(.defaultAction)
            Divider()
            HStack {
                Spacer()
                Button("Quit HostBlock") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
        }
        .padding(12)
    }

    // MARK: Licensed

    private var licensedBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(12)
            Divider()
            listsSection.padding(12)
            Divider()
            actionsSection.padding(12)
            Divider()
            footer.padding(12)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: state.protectionEnabled && state.helperInstalled ? "shield.fill" : "shield.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(state.protectionEnabled && state.helperInstalled ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HostBlock").font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Blocking", isOn: protectionBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!state.helperInstalled)
            }
            if !state.helperInstalled {
                Button("Finish Setup…") { state.finishSetup() }
                    .controlSize(.small)
            }
        }
    }

    private var statusText: String {
        if !state.helperInstalled { return "Setup required" }
        if !state.protectionEnabled { return "Blocking is off" }
        let count = Self.countFormatter.string(from: NSNumber(value: state.blockedCount)) ?? "\(state.blockedCount)"
        if let updated = state.lastUpdated {
            let ago = Self.relativeFormatter.localizedString(for: updated, relativeTo: Date())
            return "Blocking \(count) domains · updated \(ago)"
        }
        return "Blocking \(count) domains"
    }

    private var listsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blocklists")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(state.sources) { source in
                sourceRow(source)
            }
            Button("Manage Custom Lists…") { WindowManager.shared.showManageLists() }
                .buttonStyle(.link)
                .font(.caption)
        }
    }

    private func sourceRow(_ source: BlocklistSource) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(source.name).font(.callout)
                if let detail = source.detail {
                    Text(detail).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle(source.name, isOn: sourceBinding(source))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    state.updateNow()
                } label: {
                    Label("Update Now", systemImage: "arrow.clockwise")
                }
                .disabled(!state.helperInstalled || !state.protectionEnabled || state.isWorking)

                Button {
                    state.flushDNS()
                } label: {
                    Label("Flush DNS", systemImage: "wind")
                }
                .disabled(!state.helperInstalled || state.isWorking)

                Spacer()
                if state.isWorking {
                    ProgressView().controlSize(.small)
                }
            }
            if let error = state.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Licensed to")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(state.license?.email ?? "")
                        .font(.caption)
                }
                Spacer()
                Button("License Info…") { WindowManager.shared.showLicenseInfo() }
                    .controlSize(.small)
            }
            Toggle("Launch at login", isOn: launchAtLoginBinding)
                .font(.caption)
            HStack {
                Text("v\(AppConstants.appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
        }
    }

    // MARK: Bindings & formatters

    private var protectionBinding: Binding<Bool> {
        Binding(
            get: { AppState.shared.protectionEnabled },
            set: { AppState.shared.setProtection($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { AppState.shared.launchAtLogin },
            set: { AppState.shared.setLaunchAtLogin($0) }
        )
    }

    private func sourceBinding(_ source: BlocklistSource) -> Binding<Bool> {
        Binding(
            get: { AppState.shared.source(withID: source.id)?.enabled ?? false },
            set: { AppState.shared.setSource(id: source.id, enabled: $0) }
        )
    }

    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static let relativeFormatter = RelativeDateTimeFormatter()
}
