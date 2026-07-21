import HostBlockCore
import SwiftUI

struct BrowseTabView: View {
    @ObservedObject private var state = AppState.shared
    @State private var search = ""
    @State private var filter: ListCategory?

    private var results: [CatalogEntry] {
        state.catalog.filter { entry in
            let matchesCategory = filter == nil || entry.category == filter
            let matchesSearch = search.isEmpty
                || entry.name.localizedCaseInsensitiveContains(search)
                || entry.description.localizedCaseInsensitiveContains(search)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField
            filterChips
            Text("\(results.count) LIST\(results.count == 1 ? "" : "S")").sectionHeader()
            catalogList
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
            TextField("Search blocklists…", text: $search)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
        }
        .font(.system(size: 14))
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "ALL", active: filter == nil) { filter = nil }
                ForEach(ListCategory.browsable, id: \.self) { category in
                    chip(title: category.label, active: filter == category) { filter = category }
                }
            }
        }
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? Theme.surfaceElevated : Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(active ? Theme.stroke : .clear))
        }
        .buttonStyle(.plain)
    }

    private var catalogList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(results) { entry in
                    entryRow(entry)
                    if entry.id != results.last?.id {
                        Divider().overlay(Theme.separator)
                    }
                }
            }
        }
        .frame(height: 320)
    }

    private func entryRow(_ entry: CatalogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if entry.featured {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.color(for: .ads))
                    }
                    CategoryBadge(category: entry.category)
                }
                Text(entry.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(Theme.abbreviate(entry.domainCount)) domains")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 8)
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
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        } else {
            Button(action: { state.addFromCatalog(entry) }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.info)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.info.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}
