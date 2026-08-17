import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Gestaltet den Bildschirm, der statt der gesperrten App erscheint.
///
/// Die Extension darf nur eine `ShieldConfiguration` zurueckgeben — keine
/// eigene Oberflaeche, keine Animation, kein Netzwerk. Sie liest die
/// Einstellungen aus der App-Group, damit dein eigener Satz dort steht.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(subject: application.localizedDisplayName)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(subject: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(subject: webDomain.domain)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(subject: webDomain.domain)
    }

    // MARK: - Aufbau

    private func makeConfiguration(subject: String?) -> ShieldConfiguration {
        let settings = SettingsStore.loadSettings()
        let state = SettingsStore.loadRuntime()

        let title = subject.map { "\($0) ist gesperrt" } ?? "Gesperrt"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1.0),
            icon: UIImage(systemName: "moon.stars.fill"),
            title: ShieldConfiguration.Label(
                text: title,
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitleText(settings: settings, state: state),
                color: UIColor(white: 1.0, alpha: 0.72)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Zurueck",
                color: UIColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1.0)
            ),
            primaryButtonBackgroundColor: UIColor(white: 1.0, alpha: 0.92),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: secondaryButtonText(settings: settings),
                color: UIColor(white: 1.0, alpha: 0.85)
            )
        )
    }

    private func subtitleText(settings: BlockSettings, state: RuntimeState) -> String {
        var lines: [String] = []

        let message = settings.shieldMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !message.isEmpty { lines.append(message) }

        switch BlockingEngine.reason(settings: settings, state: state) {
        case .schedule(let name):
            lines.append("Sperrfenster „\(name)“ laeuft gerade.")
        case .usageBudget:
            lines.append("Dein Tagesbudget von \(settings.usageLimitMinutes) Minuten ist aufgebraucht.")
        case .none:
            break
        }

        if settings.maxUnlocksPerDay > 0 {
            let used = state.unlocksUsed()
            let left = max(0, settings.maxUnlocksPerDay - used)
            lines.append("Noch \(left) von \(settings.maxUnlocksPerDay) Entsperrungen heute.")
        }

        lines.append(unlockHint(settings: settings))
        return lines.joined(separator: "\n\n")
    }

    private func unlockHint(settings: BlockSettings) -> String {
        let breath = formatDuration(seconds: settings.breathSeconds)
        switch settings.unlockMethod {
        case .codeOnly:
            return "Zum Entsperren brauchst du deinen Code im Pausenwaechter."
        case .breathOnly:
            return "Im Pausenwaechter kannst du dich \(breath) lang durchatmen und danach weitermachen."
        case .either:
            return "Im Pausenwaechter: Code eingeben oder \(breath) durchatmen."
        case .both:
            return "Im Pausenwaechter: \(breath) durchatmen, danach den Code eingeben."
        }
    }

    private func secondaryButtonText(settings: BlockSettings) -> String {
        settings.unlockMethod == .codeOnly
            ? "Ich brauche kurz Zugriff"
            : "Durchatmen und entsperren"
    }

    private func formatDuration(seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) Sekunden" }
        let minutes = seconds / 60
        let rest = seconds % 60
        if rest == 0 {
            return minutes == 1 ? "eine Minute" : "\(minutes) Minuten"
        }
        return "\(minutes):\(String(format: "%02d", rest)) Minuten"
    }
}
