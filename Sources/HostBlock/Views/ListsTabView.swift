import HostBlockCore
import SwiftUI

struct ListsTabView: View {
    @ObservedObject private var state = AppState.shared
    @State private var addingCustom = false
    @State private var customName = ""
    @State private var customURL = ""
    @State private var addError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("ACTIVE BLOCKLISTS").sectionHeader()
                    ForEach(state.sources) { source in
                        row(source)
                    }
                    if state.sources.isEmpty {
                        Text("No lists yet. Add one from Browse or paste a URL below.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(16)
            }
            .frame(height: 300)

            Divider().overlay(Theme.separator)

            customSection
                .padding(16)

            Divider().overlay(Theme.separator)

            Button(action: { state.updateNow() }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Theme.accent)
                    Text("Update All Lists Now")
                        .foregroundStyle(Theme.textPrimary)
                    if state.isWorking {
                        ProgressView().controlSize(.small).padding(.leading, 4)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))
            }
            .buttonStyle(.plain)
            .disabled(!state.helperInstalled || !state.protectionEnabled || state.isWorking)
            .opacity((!state.helperInstalled || !state.protectionEnabled) ? 0.5 : 1)
            .padding(16)
        }
    }

    // MARK: Row

    private func row(_ source: BlocklistSource) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { AppState.shared.source(withID: source.id)?.enabled ?? false },
                set: { AppState.shared.setSource(id: source.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(GreenToggleStyle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(source.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    CategoryBadge(category: source.category)
                }
                Text("\(Theme.abbreviate(source.domainCount)) domains · \(Theme.relativeAge(source.lastFetched))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .contextMenu {
            Button("Remove List", role: .destructive) {
                state.removeSource(id: source.id)
            }
        }
    }

    // MARK: Custom list

    @ViewBuilder
    private var customSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CUSTOM LIST").sectionHeader()
            if addingCustom {
                TextField("List name (optional)", text: $customName)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))

                HStack(spacing: 8) {
                    TextField("https:// or gist URL", text: $customURL)
                        .textFieldStyle(.plain)
                        .onSubmit(submitCustom)
                        .padding(10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))

                    Button(action: submitCustom) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Theme.info, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: cancelCustom) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 38, height: 38)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))
                    }
                    .buttonStyle(.plain)
                }

                if let addError {
                    Text(addError).font(.system(size: 12)).foregroundStyle(Theme.color(for: .malware))
                }

                Label("Supports hosts files, domain lists, GitHub Gists", systemImage: "link")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Button(action: { addingCustom = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add custom blocklist URL or GitHub Gist…")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.info)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func submitCustom() {
        addError = state.addCustomList(name: customName, urlString: customURL)
        if addError == nil { cancelCustom() }
    }

    private func cancelCustom() {
        addingCustom = false
        customName = ""
        customURL = ""
        addError = nil
    }
}
