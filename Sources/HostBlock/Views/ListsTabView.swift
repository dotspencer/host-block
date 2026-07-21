import HostBlockCore
import SwiftUI

struct ListsTabView: View {
    @ObservedObject private var state = AppState.shared
    @State private var addingCustom = false
    @State private var customName = ""
    @State private var customURL = ""
    @State private var addError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: s(0)) {
            ScrollView {
                VStack(alignment: .leading, spacing: s(14)) {
                    Text("ACTIVE BLOCKLISTS").sectionHeader()
                    ForEach(state.sources) { source in
                        row(source)
                    }
                    if state.sources.isEmpty {
                        Text("No lists yet. Add one from Browse or paste a URL below.")
                            .font(.system(size: s(12)))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(s(16))
            }
            .frame(height: s(300))

            Divider().overlay(Theme.separator)

            customSection
                .padding(s(16))

            Divider().overlay(Theme.separator)

            Button(action: { state.updateNow() }) {
                HStack(spacing: s(8)) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Theme.accent)
                    Text("Update All Lists Now")
                        .foregroundStyle(Theme.textPrimary)
                    if state.isWorking {
                        ProgressView().controlSize(.small).padding(.leading, s(4))
                    }
                }
                .font(.system(size: s(13), weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, s(12))
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: s(8)))
                .overlay(RoundedRectangle(cornerRadius: s(8)).stroke(Theme.stroke))
            }
            .buttonStyle(.plain)
            .disabled(!state.helperInstalled || !state.protectionEnabled || state.isWorking)
            .opacity((!state.helperInstalled || !state.protectionEnabled) ? 0.5 : 1)
            .padding(s(16))
        }
    }

    // MARK: Row

    private func row(_ source: BlocklistSource) -> some View {
        HStack(alignment: .center, spacing: s(12)) {
            Toggle("", isOn: Binding(
                get: { AppState.shared.source(withID: source.id)?.enabled ?? false },
                set: { AppState.shared.setSource(id: source.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(GreenToggleStyle())

            VStack(alignment: .leading, spacing: s(3)) {
                HStack(spacing: s(8)) {
                    Text(source.name)
                        .font(.system(size: s(14), weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    CategoryBadge(category: source.category)
                }
                Text("\(Theme.abbreviate(source.domainCount)) domains · \(Theme.relativeAge(source.lastFetched))")
                    .font(.system(size: s(12), design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: s(0))
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
        VStack(alignment: .leading, spacing: s(12)) {
            Text("CUSTOM LIST").sectionHeader()
            if addingCustom {
                TextField("List name (optional)", text: $customName)
                    .textFieldStyle(.plain)
                    .padding(s(10))
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: s(8)))
                    .overlay(RoundedRectangle(cornerRadius: s(8)).stroke(Theme.stroke))

                HStack(spacing: s(8)) {
                    TextField("https:// or gist URL", text: $customURL)
                        .textFieldStyle(.plain)
                        .onSubmit(submitCustom)
                        .padding(s(10))
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: s(8)))
                        .overlay(RoundedRectangle(cornerRadius: s(8)).stroke(Theme.stroke))

                    Button(action: submitCustom) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .frame(width: s(38), height: s(38))
                            .background(Theme.info, in: RoundedRectangle(cornerRadius: s(8)))
                    }
                    .buttonStyle(.plain)

                    Button(action: cancelCustom) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: s(38), height: s(38))
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: s(8)))
                            .overlay(RoundedRectangle(cornerRadius: s(8)).stroke(Theme.stroke))
                    }
                    .buttonStyle(.plain)
                }

                if let addError {
                    Text(addError).font(.system(size: s(12))).foregroundStyle(Theme.color(for: .malware))
                }

                Label("Supports hosts files, domain lists, GitHub Gists", systemImage: "link")
                    .font(.system(size: s(12)))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Button(action: { addingCustom = true }) {
                    HStack(spacing: s(8)) {
                        Image(systemName: "plus")
                        Text("Add custom blocklist URL or GitHub Gist…")
                    }
                    .font(.system(size: s(14), weight: .medium))
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
