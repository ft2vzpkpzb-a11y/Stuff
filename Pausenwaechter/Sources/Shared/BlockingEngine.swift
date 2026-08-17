import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Der eine Ort, an dem entschieden wird: sperren oder nicht.
///
/// Die Logik ist bewusst *zustandsfrei ableitbar*. `refresh()` liest die
/// Einstellungen und den Laufzeitzustand, rechnet den Sollzustand aus und
/// stellt ihn her. Dadurch heilt sich das System selbst: egal ob die App,
/// der Monitor oder der Sperrbildschirm den Aufruf ausloest, das Ergebnis ist
/// dasselbe. Verpasste Systemereignisse fuehren nicht zu einer dauerhaft
/// falschen Sperre.
public enum BlockingEngine {

    /// Eigener benannter Store. Jeder Zugriff liefert einen frischen Griff auf
    /// denselben Systemspeicher — das ist der von Apple vorgesehene Weg.
    private static var managedStore: ManagedSettingsStore {
        ManagedSettingsStore(named: .pausenwaechter)
    }

    private static var activityCenter: DeviceActivityCenter {
        DeviceActivityCenter()
    }

    // MARK: - Sollzustand

    public enum BlockReason: Equatable {
        case none
        case schedule(windowName: String)
        case usageBudget
    }

    /// Warum gerade gesperrt wird — unabhaengig von einer aktiven Entsperrung.
    public static func reason(
        settings: BlockSettings = SettingsStore.loadSettings(),
        state: RuntimeState = SettingsStore.loadRuntime(),
        at date: Date = Date()
    ) -> BlockReason {
        guard settings.isArmed else { return .none }

        if let window = settings.activeWindow(at: date) {
            return .schedule(windowName: window.name)
        }
        if settings.usageLimitEnabled, state.isBudgetExceeded(at: date) {
            return .usageBudget
        }
        return .none
    }

    /// Muss der Schild jetzt stehen?
    public static func shouldBlock(
        settings: BlockSettings = SettingsStore.loadSettings(),
        state: RuntimeState = SettingsStore.loadRuntime(),
        at date: Date = Date()
    ) -> Bool {
        guard reason(settings: settings, state: state, at: date) != .none else { return false }
        return !state.isUnlocked(at: date)
    }

    // MARK: - Sollzustand herstellen

    /// Rechnet den Sollzustand aus und wendet ihn an. Idempotent.
    public static func refresh(at date: Date = Date()) {
        let settings = SettingsStore.loadSettings()
        var state = SettingsStore.loadRuntime()

        // Abgelaufene Entsperrung aufraeumen, damit die Anzeige nicht luegt.
        if let until = state.unlockedUntil, until <= date {
            state.unlockedUntil = nil
            SettingsStore.saveRuntime(state)
            activityCenter.stopMonitoring([.unlockWindow])
        }

        if shouldBlock(settings: settings, state: state, at: date) {
            applyShield(settings: settings)
        } else {
            removeShield()
        }
    }

    private static func applyShield(settings: BlockSettings) {
        let selection = SettingsStore.loadSelection()
        let store = managedStore

        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens

        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)

        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens

        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)

        // Verhindert, dass du dich durch Loeschen des Pausenwaechters
        // aus der eigenen Regel herausmogelst.
        store.application.denyAppRemoval = settings.preventAppDeletion ? true : nil
    }

    private static func removeShield() {
        let store = managedStore
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        store.application.denyAppRemoval = nil
    }

    /// Alles zuruecknehmen — Schild weg, alle Beobachtungen beendet.
    public static func disarmCompletely() {
        removeShield()
        activityCenter.stopMonitoring()
    }

    // MARK: - Beobachtung planen

    /// Registriert alle Zeitplaene neu. Nach jeder Aenderung der
    /// Einstellungen aufrufen.
    public static func rescheduleMonitoring() {
        let settings = SettingsStore.loadSettings()
        let center = activityCenter

        // Die Entsperr-Beobachtung nicht abraeumen — sie haengt an einer
        // laufenden Freigabe, nicht an der Konfiguration.
        let toStop = center.activities.filter { $0 != .unlockWindow }
        if !toStop.isEmpty { center.stopMonitoring(toStop) }

        guard settings.isArmed else { return }

        scheduleWindows(settings.windows, center: center)

        if settings.usageLimitEnabled {
            scheduleUsageBudget(minutes: settings.usageLimitMinutes, center: center)
        }
    }

    private static func scheduleWindows(_ windows: [BlockWindow], center: DeviceActivityCenter) {
        for (index, window) in windows.enumerated() where window.isEnabled {
            // Ein DeviceActivitySchedule kann keine Wochentage. Die
            // Wochentagspruefung passiert in `BlockWindow.isActive`; hier
            // geht es nur darum, die Extension an den Grenzen zu wecken.
            if window.crossesMidnight {
                // Abendhaelfte bis kurz vor Mitternacht.
                start(
                    center,
                    name: .window(index, half: 0),
                    from: DateComponents(hour: window.start.hour, minute: window.start.minute),
                    to: DateComponents(hour: 23, minute: 59)
                )
                // Morgenhaelfte ab Mitternacht.
                start(
                    center,
                    name: .window(index, half: 1),
                    from: DateComponents(hour: 0, minute: 0),
                    to: DateComponents(hour: window.end.hour, minute: window.end.minute)
                )
            } else {
                start(
                    center,
                    name: .window(index, half: 0),
                    from: DateComponents(hour: window.start.hour, minute: window.start.minute),
                    to: DateComponents(hour: window.end.hour, minute: window.end.minute)
                )
            }
        }
    }

    private static func start(
        _ center: DeviceActivityCenter,
        name: DeviceActivityName,
        from start: DateComponents,
        to end: DateComponents,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
    ) {
        // Das System verlangt mindestens 15 Minuten Abstand zwischen
        // Start und Ende. Kuerzere Fenster lehnt es ab.
        guard minutesBetween(start, end) >= 15 else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: end,
            repeats: true
        )
        do {
            try center.startMonitoring(name, during: schedule, events: events)
        } catch {
            // Ohne erteilte Berechtigung schlaegt das fehl. Kein Grund
            // abzustuerzen — die App zeigt den Zustand ohnehin an.
            NSLog("Pausenwaechter: Beobachtung \(name.rawValue) fehlgeschlagen: \(error)")
        }
    }

    private static func minutesBetween(_ start: DateComponents, _ end: DateComponents) -> Int {
        let startMinutes = (start.hour ?? 0) * 60 + (start.minute ?? 0)
        let endMinutes = (end.hour ?? 0) * 60 + (end.minute ?? 0)
        let delta = endMinutes - startMinutes
        return delta > 0 ? delta : delta + 1440
    }

    private static func scheduleUsageBudget(minutes: Int, center: DeviceActivityCenter) {
        let selection = SettingsStore.loadSelection()
        let event = makeEvent(selection: selection, thresholdMinutes: max(1, minutes))

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        do {
            try center.startMonitoring(
                .usageBudget,
                during: schedule,
                events: [.budgetReached: event]
            )
        } catch {
            NSLog("Pausenwaechter: Tagesbudget konnte nicht gesetzt werden: \(error)")
        }
    }

    private static func makeEvent(
        selection: FamilyActivitySelection,
        thresholdMinutes: Int
    ) -> DeviceActivityEvent {
        let threshold = DateComponents(minute: thresholdMinutes)
        if #available(iOS 17.4, *) {
            return DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: threshold,
                includesPastActivity: false
            )
        }
        return DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: threshold
        )
    }

    // MARK: - Entsperren

    public enum UnlockError: LocalizedError {
        case dailyLimitReached(Int)

        public var errorDescription: String? {
            switch self {
            case .dailyLimitReached(let limit):
                return "Du hast dein Tageslimit von \(limit) Entsperrungen erreicht."
            }
        }
    }

    /// Ist noch eine Entsperrung uebrig?
    public static func canUnlock(
        settings: BlockSettings = SettingsStore.loadSettings(),
        state: RuntimeState = SettingsStore.loadRuntime(),
        at date: Date = Date()
    ) -> Bool {
        guard settings.maxUnlocksPerDay > 0 else { return true }
        return state.unlocksUsed(at: date) < settings.maxUnlocksPerDay
    }

    /// Gibt die Apps fuer die eingestellte Dauer frei.
    ///
    /// Die Freigabe endet, was immer zuerst eintritt:
    /// die verbrauchte Nutzungszeit oder das Ende des Wanduhr-Fensters.
    @discardableResult
    public static func grantUnlock(at date: Date = Date()) throws -> Date {
        let settings = SettingsStore.loadSettings()
        let state = SettingsStore.loadRuntime()

        guard canUnlock(settings: settings, state: state, at: date) else {
            throw UnlockError.dailyLimitReached(settings.maxUnlocksPerDay)
        }

        let minutes = max(1, settings.unlockMinutes)
        // Wanduhr-Grenze als Sicherheitsnetz. Sie liegt bewusst ueber der
        // Nutzungszeit, weil das System Zeitplaene unter 15 Minuten ablehnt.
        let wallClockMinutes = max(15, minutes + 10)
        let until = date.addingTimeInterval(TimeInterval(wallClockMinutes * 60))
        let today = DayKey.of(date)

        SettingsStore.mutateRuntime { state in
            state.unlockedUntil = until
            state.pendingRequestAt = nil
            if state.unlockCountDay == today {
                state.unlockCount += 1
            } else {
                state.unlockCountDay = today
                state.unlockCount = 1
            }
            state.totalUnlocks += 1
        }

        removeShield()
        startUnlockMonitoring(usageMinutes: minutes, wallClockMinutes: wallClockMinutes, from: date)
        return until
    }

    private static func startUnlockMonitoring(
        usageMinutes: Int,
        wallClockMinutes: Int,
        from date: Date
    ) {
        let center = activityCenter
        center.stopMonitoring([.unlockWindow])

        let calendar = Calendar.current
        let endDate = date.addingTimeInterval(TimeInterval(wallClockMinutes * 60))

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: date),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: endDate),
            repeats: false
        )

        let selection = SettingsStore.loadSelection()
        let event = makeEvent(selection: selection, thresholdMinutes: usageMinutes)

        do {
            try center.startMonitoring(
                .unlockWindow,
                during: schedule,
                events: [.unlockElapsed: event]
            )
        } catch {
            NSLog("Pausenwaechter: Entsperrfenster nicht ueberwachbar: \(error)")
        }
    }

    /// Freigabe sofort beenden — „ich bin fertig“.
    public static func endUnlockEarly() {
        SettingsStore.mutateRuntime { $0.unlockedUntil = nil }
        activityCenter.stopMonitoring([.unlockWindow])
        refresh()
    }

    // MARK: - Ereignisse aus der Monitor-Extension

    public static func handleBudgetReached(at date: Date = Date()) {
        SettingsStore.mutateRuntime { $0.budgetExceededOn = DayKey.of(date) }
        refresh(at: date)
    }

    public static func handleDayRollover(at date: Date = Date()) {
        SettingsStore.mutateRuntime { state in
            state.budgetExceededOn = nil
            state.unlockCountDay = DayKey.of(date)
            state.unlockCount = 0
        }
        refresh(at: date)
    }

    public static func handleUnlockExpired(at date: Date = Date()) {
        SettingsStore.mutateRuntime { $0.unlockedUntil = nil }
        activityCenter.stopMonitoring([.unlockWindow])
        refresh(at: date)
    }
}
