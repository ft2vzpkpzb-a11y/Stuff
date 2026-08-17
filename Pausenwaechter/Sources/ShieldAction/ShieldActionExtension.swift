import ManagedSettings
import Foundation

/// Reagiert auf die zwei Knoepfe des Sperrbildschirms.
///
/// Wichtige Einschraenkung von iOS: diese Extension darf keine andere App
/// oeffnen und keine Oberflaeche zeigen. Sie kann nur schliessen, offen
/// lassen oder erneut anzeigen. Deshalb hinterlegt der zweite Knopf hier
/// eine Anfrage im geteilten Speicher — beim naechsten Start des
/// Pausenwaechters springt der direkt in den Entsperr-Dialog.
class ShieldActionExtension: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            // „Zurueck“ — Absicht durchgehalten. Zaehlen wir mit.
            SettingsStore.mutateRuntime { $0.totalAborted += 1 }
            return .close

        case .secondaryButtonPressed:
            // Anfrage vormerken und die gesperrte App schliessen.
            SettingsStore.mutateRuntime { $0.pendingRequestAt = Date() }
            return .close

        @unknown default:
            return .close
        }
    }
}
