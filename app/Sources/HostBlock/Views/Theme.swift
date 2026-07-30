import HostBlockCore
import SwiftUI

/// Colors, fonts, and small shared building blocks for the redesigned dropdown.
enum Theme {
    static let panelWidth: CGFloat = 350

    // Dark surface palette (the dropdown commits to a dark look). Values sampled from
    // the reference mockups: a flat neutral charcoal panel with slightly lighter surfaces.
    static let background = Color(red: 0.118, green: 0.118, blue: 0.129)      // #1e1e21
    static let surface = Color(red: 0.153, green: 0.153, blue: 0.165)         // #27272a
    static let surfaceElevated = Color(red: 0.204, green: 0.208, blue: 0.231) // #34353b
    static let stroke = Color.white.opacity(0.09)
    static let separator = Color.white.opacity(0.07)

    static let accent = Color(red: 0.29, green: 0.83, blue: 0.5)   // green
    static let info = Color(red: 0.23, green: 0.51, blue: 0.96)     // blue
    static let danger = Color(red: 0.94, green: 0.35, blue: 0.35)  // red
    static let warning = Color(red: 0.96, green: 0.65, blue: 0.14) // orange

    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)

    /// Every text style routes through here, so the app's font family lives in one
    /// place. Swap the `design` (or use `.custom(...)`) to restyle all text at once.
    /// Currently the macOS system font (SF Pro), with SF Mono when `mono` is true.
    static func font(_ size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false) -> Font {
        .system(size: size, weight: weight, design: mono ? .monospaced : .default)
    }

    /// "48000" -> "48K", "246633" -> "246K", small values stay exact.
    static func abbreviate(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return "\(count / 1000)K"
        }
        return "\(count)"
    }
}

/// Small status pill in the header (ACTIVE / PAUSED).
struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(Theme.font(9, weight: .bold, mono: true))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Green pill toggle matching the mockups.
struct GreenToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(configuration.isOn ? Theme.accent : Color.white.opacity(0.18))
                .frame(width: 35, height: 19)
                .overlay(
                    Circle()
                        .fill(.white)
                        .padding(2)
                        .frame(width: 19, height: 19)
                        .offset(x: configuration.isOn ? 8 : -8)
                )
                .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func sectionHeader() -> some View {
        self
            .font(Theme.font(10, weight: .semibold, mono: true))
            .tracking(1.0)
            .foregroundStyle(Theme.textSecondary)
    }
}
