import HostBlockCore
import SwiftUI

struct LicenseInfoView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        Group {
            if let license = state.license {
                details(license)
            } else {
                Text("No active license.")
                    .foregroundStyle(.secondary)
                    .padding(40)
            }
        }
    }

    private func details(_ license: LicenseInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(license.productName ?? "HostBlock")
                        .font(.title3.bold())
                    Text("\(license.tier.displayName) license · \(license.tier.deviceLimitDescription.lowercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                row("Name", license.fullName ?? "—")
                row("Email", license.email)
                row("License", "\(license.tier.displayName) (\(license.tier.deviceLimitDescription))")
                row("Key", license.licenseKey, monospaced: true)
                row("Purchased", license.purchaseDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
                row("Card", cardText(license))
                row("Order #", license.orderNumber.map(String.init) ?? "—")
            }

            Divider()

            Text("This license belongs to the person shown above. Anyone this key is shared with can see these purchase details.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 420)
    }

    private func row(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(monospaced ? .caption.monospaced() : .caption)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func cardText(_ license: LicenseInfo) -> String {
        switch (license.cardType?.capitalized, license.cardVisual) {
        case let (type?, visual?): return "\(type) \(visual)"
        case let (nil, visual?): return visual
        case let (type?, nil): return type
        default: return "—"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}
