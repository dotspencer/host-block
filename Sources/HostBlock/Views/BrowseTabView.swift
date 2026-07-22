import HostBlockCore
import SwiftUI

struct BrowseTabView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(state.catalog) { entry in
                    entryRow(entry)
                    if entry.id != state.catalog.last?.id {
                        Divider().overlay(Theme.separator)
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 360)
    }

    private func entryRow(_ entry: CatalogEntry) -> some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(entry.description)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("\(Theme.abbreviate(entry.domainCount)) domains")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                    if let url = URL(string: entry.url) {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.info)
                        }
                        .help("View the raw list")
                    }
                }
            }
            Spacer(minLength: 7)
            addButton(entry)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func addButton(_ entry: CatalogEntry) -> some View {
        if state.isInstalled(catalogID: entry.id) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                Text("Added")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
        } else {
            Button(action: { state.addFromCatalog(entry) }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.info)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Theme.info.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
    }
}
