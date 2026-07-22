import HostBlockCore
import SwiftUI

struct BrowseTabView: View {
    @ObservedObject private var state = AppState.shared
    @State private var search = ""
    @State private var filter: ListCategory?

    private var results: [CatalogEntry] {
        let matches = state.catalog.filter { entry in
            let matchesCategory = filter == nil || entry.category == filter
            let matchesSearch = search.isEmpty
                || entry.name.localizedCaseInsensitiveContains(search)
                || entry.description.localizedCaseInsensitiveContains(search)
            return matchesCategory && matchesSearch
        }
        // Featured first, preserving each group's original catalog order.
        return matches.enumerated()
            .sorted { lhs, rhs in
                lhs.element.featured != rhs.element.featured
                    ? lhs.element.featured
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            searchField
            filterChips
            Text("\(results.count) LIST\(results.count == 1 ? "" : "S")").sectionHeader()
            catalogList
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
            TextField("Search blocklists…", text: $search)
                .textFieldStyle(.plain)
                .tint(.white)
                .foregroundStyle(Theme.textPrimary)
        }
        .font(.system(size: 12))
        .padding(9)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.stroke))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
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
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
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
        .frame(height: 282)
    }

    private func entryRow(_ entry: CatalogEntry) -> some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(entry.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if entry.featured {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.color(for: .ads))
                    }
                    CategoryBadge(category: entry.category)
                }
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
        .padding(.vertical, 11)
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
