import Foundation
import Combine
import FamilyControls
import SwiftUI

/// Zustand der Oberflaeche. Haelt Einstellungen und Auswahl im Speicher,
/// schreibt jede Aenderung sofort in die App-Group und plant die
/// Beobachtung neu, damit App und Extensions nie auseinanderlaufen.
@MainActor
final class AppModel: ObservableObject {

    @Published var settings: BlockSettings {
        didSet { persistSettings(from: oldValue) }
    }

    @Published var selection: FamilyActivitySelection {
        didSet { persistSelection() }
    }

    @Published private(set) var runtime: RuntimeState
    @Published private(set) var authorization: AuthorizationStatus = .notDetermined
    @Published var authorizationError: String?
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            AppGroup.defaults.set(hasCompletedOnboarding, forKey: "onboarding.done")
        }
    }

    enum AuthorizationStatus: Equatable {
        case notDetermined
        case approved
        case denied
    }

    /// Verhindert, dass das Zurueckschreiben beim Laden erneut speichert.
    private var isLoading = true
    private var ticker: AnyCancellable?

    init() {
        settings = SettingsStore.loadSettings()
        selection = SettingsStore.loadSelection()
        runtime = SettingsStore.loadRuntime()
        hasCompletedOnboarding = AppGroup.defaults.bool(forKey: "onboarding.done")
        isLoading = false

        refreshAuthorization()
        startTicker()
    }

    // MARK: - Speichern

    private func persistSettings(from oldValue: BlockSettings) {
        guard !isLoading, settings != oldValue else { return }
        SettingsStore.saveSettings(settings)

        if settings.isArmed {
            BlockingEngine.rescheduleMonitoring()
            BlockingEngine.refresh()
        } else {
            BlockingEngine.disarmCompletely()
        }
        reloadRuntime()
    }

    private func persistSelection() {
        guard !isLoading else { return }
        SettingsStore.saveSelection(selection)
        if settings.isArmed {
            BlockingEngine.rescheduleMonitoring()
            BlockingEngine.refresh()
        }
    }

    // MARK: - Aktualisieren

    /// Bei jedem Wechsel in den Vordergrund aufrufen.
    func refreshFromForeground() {
        reloadRuntime()
        refreshAuthorization()
        BlockingEngine.refresh()
        reloadRuntime()
    }

    func reloadRuntime() {
        runtime = SettingsStore.loadRuntime()
    }

    private func startTicker() {
        // Sekundentakt, aber nur solange eine Freigabe laeuft — das ist die
        // einzige Anzeige, die von aussen mitzaehlen muss. Sonst wuerde die
        // ganze Oberflaeche jede Sekunde neu gezeichnet, auch beim Tippen.
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let until = self.runtime.unlockedUntil else { return }

                if until <= Date() {
                    BlockingEngine.refresh()
                    self.reloadRuntime()
                } else {
                    // Restzeit hat sich geaendert, der Wert selbst nicht.
                    self.objectWillChange.send()
                }
            }
    }

    // MARK: - Berechtigung

    func refreshAuthorization() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: authorization = .approved
        case .denied: authorization = .denied
        case .notDetermined: authorization = .notDetermined
        @unknown default: authorization = .notDetermined
        }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationError = nil
        } catch {
            authorizationError = Self.describe(error)
        }
        refreshAuthorization()
    }

    private static func describe(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("cancel") {
            return "Die Anfrage wurde abgebrochen. Ohne die Freigabe kann der Pausenwaechter keine Apps sperren."
        }
        return "Bildschirmzeit-Freigabe fehlgeschlagen: \(text)"
    }

    // MARK: - Abgeleiteter Zustand

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    var selectionCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    var blockReason: BlockingEngine.BlockReason {
        BlockingEngine.reason(settings: settings, state: runtime)
    }

    var isCurrentlyBlocked: Bool {
        BlockingEngine.shouldBlock(settings: settings, state: runtime)
    }

    var isUnlocked: Bool { runtime.isUnlocked() }

    var unlockRemaining: TimeInterval {
        guard let until = runtime.unlockedUntil else { return 0 }
        return max(0, until.timeIntervalSinceNow)
    }

    /// Es gibt eine offene Anfrage vom Sperrbildschirm, wenn sie frisch ist.
    var hasPendingRequest: Bool {
        guard let at = runtime.pendingRequestAt else { return false }
        return Date().timeIntervalSince(at) < 300 && isCurrentlyBlocked
    }

    func clearPendingRequest() {
        SettingsStore.mutateRuntime { $0.pendingRequestAt = nil }
        reloadRuntime()
    }

    /// Alles bereit, um scharf zu schalten?
    var setupProblems: [String] {
        var problems: [String] = []
        if authorization != .approved {
            problems.append("Bildschirmzeit-Freigabe fehlt")
        }
        if !hasSelection {
            problems.append("Keine Apps ausgewaehlt")
        }
        if settings.unlockMethod.allowsCode, !Passcode.isSet {
            problems.append("Kein Entsperr-Code gesetzt")
        }
        if !settings.usageLimitEnabled, settings.windows.allSatisfy({ !$0.isEnabled }) {
            problems.append("Kein Zeitfenster und kein Tagesbudget aktiv")
        }
        return problems
    }

    var canArm: Bool { setupProblems.isEmpty }

    // MARK: - Aktionen

    /// Gibt die Apps frei und liefert zurueck, bis wann spaetestens.
    @discardableResult
    func grantUnlock() throws -> Date {
        let until = try BlockingEngine.grantUnlock()
        reloadRuntime()
        return until
    }

    func endUnlockEarly() {
        BlockingEngine.endUnlockEarly()
        reloadRuntime()
    }

    func recordCompletedBreath() {
        SettingsStore.mutateRuntime { $0.totalBreathsCompleted += 1 }
        reloadRuntime()
    }

    func recordAbort() {
        SettingsStore.mutateRuntime { $0.totalAborted += 1 }
        reloadRuntime()
    }
}
