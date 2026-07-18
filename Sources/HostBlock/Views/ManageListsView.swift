import HostBlockCore
import SwiftUI

struct ManageListsView: View {
    @ObservedObject private var state = AppState.shared
    @State private var name = ""
    @State private var urlString = ""
    @State private var addError: String?

    private var customLists: [BlocklistSource] {
        state.sources.filter { !$0.isBuiltIn }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a custom blocklist")
                .font(.headline)
            Text("Any URL that returns a plain-text domain list, hosts file, or Adblock-style list — a raw GitHub Gist works great.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TextField("Name", text: $name)
                    .frame(width: 120)
                TextField("https://gist.githubusercontent.com/…", text: $urlString)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .textFieldStyle(.roundedBorder)

            if let addError {
                Text(addError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            if customLists.isEmpty {
                Text("No custom lists yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(customLists) { list in
                            listRow(list)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func listRow(_ list: BlocklistSource) -> some View {
        HStack(spacing: 10) {
            Toggle(list.name, isOn: Binding(
                get: { AppState.shared.source(withID: list.id)?.enabled ?? false },
                set: { AppState.shared.setSource(id: list.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 1) {
                Text(list.name).font(.callout)
                Text(list.url)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                state.removeCustomList(id: list.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove this list")
        }
        .padding(.vertical, 2)
    }

    private func add() {
        addError = state.addCustomList(name: name, urlString: urlString)
        if addError == nil {
            name = ""
            urlString = ""
        }
    }
}
