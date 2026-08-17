import SwiftUI

/// Ein kleiner, ruhiger Farbsatz. Dunkle Tiefe, ein warmer Akzent.
enum Theme {
    static let accent = Color(red: 0.42, green: 0.62, blue: 0.98)
    static let calm = Color(red: 0.38, green: 0.78, blue: 0.70)
    static let warn = Color(red: 0.96, green: 0.63, blue: 0.31)
    static let danger = Color(red: 0.93, green: 0.42, blue: 0.42)

    static let cardBackground = Color(.secondarySystemGroupedBackground)
}

/// Karte mit Titelzeile — das wiederkehrende Layoutelement der App.
struct Card<Content: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = Theme.accent
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    /// Grosser, gut treffbarer Knopf.
    func primaryButtonStyle(tint: Color = Theme.accent, enabled: Bool = true) -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                (enabled ? tint : Color.gray.opacity(0.4)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }
}

/// Sekunden als „1:05“ bzw. „45 s“.
func formatSeconds(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds) s" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

/// Restzeit als „12 Min 30 s“.
func formatRemaining(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded()))
    let minutes = total / 60
    let seconds = total % 60
    if minutes == 0 { return "\(seconds) s" }
    return "\(minutes) Min \(String(format: "%02d", seconds)) s"
}

/// Minutenwert als „1 Std 30 Min“.
func formatMinutes(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes) Min" }
    let hours = minutes / 60
    let rest = minutes % 60
    return rest == 0 ? "\(hours) Std" : "\(hours) Std \(rest) Min"
}
