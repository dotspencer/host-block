import HostBlockCore
import SwiftUI

struct ListsTabView: View {
    @ObservedObject private var state = AppState.shared
    @State private var addingCustom = false
    @State private var customName = ""
    @State private var customURL = ""
    @State private var addError: String?
    @State private var hoveredID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ACTIVE BLOCKLISTS").sectionHeader()
                    ForEach(state.sources) { source in
                        row(source)
                    }
                    if state.sources.isEmpty {
                        Text("No lists yet. Add one from Browse or paste a URL below.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(14)
            }
            .frame(height: 264)

            Divider().overlay(Theme.separator)

            customSection
                .padding(14)

            Divider().overlay(Theme.separator)

            Button(action: { state.updateNow() }) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Theme.accent)
                    Text("Update All Lists Now")
                        .foregroundStyle(Theme.textPrimary)
                }
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.stroke))
                // Spinner floats in an overlay so it stays out of the button's layout
                // flow — toggling it doesn't re-lay-out the button content, which is
                // what made MenuBarExtra re-anchor and shift the window a few pixels.
                .overlay(alignment: .trailing) {
                    if state.isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 11)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!state.helperInstalled || !state.protectionEnabled || state.isWorking)
            .opacity((!state.helperInstalled || !state.protectionEnabled) ? 0.5 : 1)
            .padding(14)
        }
    }

    // MARK: Row

    private func row(_ source: BlocklistSource) -> some View {
        let hovered = hoveredID == source.id
        return HStack(alignment: .center, spacing: 11) {
            Toggle("", isOn: Binding(
                get: { AppState.shared.source(withID: source.id)?.enabled ?? false },
                set: { AppState.shared.setSource(id: source.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(GreenToggleStyle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(source.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    CategoryBadge(category: source.category)
                }
                Text("\(Theme.abbreviate(source.domainCount)) domains · \(Theme.relativeAge(source.lastFetched))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 7)

            // Trash stays in the layout (opacity-toggled) so revealing it on hover
            // doesn't shift the row content.
            Button(action: { state.removeSource(id: source.id) }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color(for: .malware))
            }
            .buttonStyle(.plain)
            .help("Remove \(source.name)")
            .opacity(hovered ? 1 : 0)
            .allowsHitTesting(hovered)
        }
        // Highlight extends slightly beyond the content so the hover band spans the
        // row like the mockup, without moving the content.
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(hovered ? Theme.surface : Color.clear)
                .padding(.horizontal, -7)
                .padding(.vertical, -5)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering { hoveredID = source.id }
            else if hoveredID == source.id { hoveredID = nil }
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
        VStack(alignment: .leading, spacing: 11) {
            Text("CUSTOM LIST").sectionHeader()
            if addingCustom {
                TextField("List name (optional)", text: $customName)
                    .textFieldStyle(.plain)
                    .padding(9)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.stroke))

                HStack(spacing: 7) {
                    TextField("https:// or gist URL", text: $customURL)
                        .textFieldStyle(.plain)
                        .onSubmit(submitCustom)
                        .padding(9)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.stroke))

                    Button(action: submitCustom) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .frame(width: 33, height: 33)
                            .background(Theme.info, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)

                    Button(action: cancelCustom) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 33, height: 33)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.stroke))
                    }
                    .buttonStyle(.plain)
                }

                if let addError {
                    Text(addError).font(.system(size: 11)).foregroundStyle(Theme.color(for: .malware))
                }

                Label("Supports hosts files, domain lists, GitHub Gists", systemImage: "link")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Button(action: { addingCustom = true }) {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                        Text("Add custom blocklist URL or GitHub Gist…")
                    }
                    .font(.system(size: 12, weight: .medium))
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
