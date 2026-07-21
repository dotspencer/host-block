import HostBlockCore
import SwiftUI

/// Global UI scale for the dropdown — lower is more compact. Every fixed font size,
/// padding, corner radius, and frame dimension is multiplied by this via `s()`, so
/// the whole panel scales proportionally from one knob.
let uiScale: CGFloat = 0.88
@inline(__always) func s(_ value: CGFloat) -> CGFloat { value * uiScale }

/// Colors, fonts, and small shared building blocks for the redesigned dropdown.
enum Theme {
    static let panelWidth: CGFloat = s(360)

    // Dark surface palette (the dropdown commits to a dark look). Values sampled from
    // the reference mockups: a flat neutral charcoal panel with slightly lighter surfaces.
    static let background = Color(red: 0.118, green: 0.118, blue: 0.129)      // #1e1e21
    static let surface = Color(red: 0.153, green: 0.153, blue: 0.165)         // #27272a
    static let surfaceElevated = Color(red: 0.204, green: 0.208, blue: 0.231) // #34353b
    static let stroke = Color.white.opacity(0.09)
    static let separator = Color.white.opacity(0.07)

    static let accent = Color(red: 0.29, green: 0.83, blue: 0.5)   // green
    static let info = Color(red: 0.23, green: 0.51, blue: 0.96)     // blue

    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)

    static func color(for category: ListCategory) -> Color {
        switch category {
        case .ads: return Color(red: 0.96, green: 0.65, blue: 0.14)      // orange
        case .trackers: return Color(red: 0.66, green: 0.35, blue: 0.97) // purple
        case .malware: return Color(red: 0.94, green: 0.35, blue: 0.35)  // red
        case .privacy: return Color(red: 0.23, green: 0.51, blue: 0.96)  // blue
        case .adult: return Color(red: 0.93, green: 0.38, blue: 0.60)    // pink
        case .custom: return Color.white.opacity(0.45)                   // gray
        }
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

    /// Compact "2h ago" / "just now" style used for per-list freshness.
    static func relativeAge(_ date: Date?) -> String {
        guard let date else { return "never" }
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86_400))d ago"
    }
}

/// Uppercase color-coded category pill (ADS, TRACKERS, MALWARE, …).
struct CategoryBadge: View {
    let category: ListCategory
    var body: some View {
        Text(category.label)
            .font(.system(size: s(10), weight: .bold, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(Theme.color(for: category))
            .padding(.horizontal, s(6))
            .padding(.vertical, s(2))
            .background(Theme.color(for: category).opacity(0.15), in: RoundedRectangle(cornerRadius: s(4)))
    }
}

/// Small status pill in the header (ACTIVE / PAUSED).
struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: s(10), weight: .bold, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, s(6))
            .padding(.vertical, s(2))
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: s(4)))
    }
}

/// Green pill toggle matching the mockups.
struct GreenToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: s(11))
                .fill(configuration.isOn ? Theme.accent : Color.white.opacity(0.18))
                .frame(width: s(40), height: s(22))
                .overlay(
                    Circle()
                        .fill(.white)
                        .padding(s(2))
                        .frame(width: s(22), height: s(22))
                        .offset(x: configuration.isOn ? s(9) : -s(9))
                )
                .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func sectionHeader() -> some View {
        self
            .font(.system(size: s(11), weight: .semibold, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(Theme.textSecondary)
    }
}
