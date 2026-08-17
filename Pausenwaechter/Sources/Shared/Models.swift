import Foundation

// MARK: - Entsperr-Methode

public enum UnlockMethod: String, Codable, CaseIterable, Sendable {
    /// Nur der selbst gesetzte Code entsperrt.
    case codeOnly
    /// Nur die Atempause entsperrt — kein Code noetig, aber du musst warten.
    case breathOnly
    /// Beides ist erlaubt, du waehlst im Moment der Sperre.
    case either
    /// Beides ist noetig: erst atmen, dann Code. Fuer harte Tage.
    case both

    public var allowsCode: Bool { self != .breathOnly }
    public var allowsBreath: Bool { self != .codeOnly }
    public var requiresBoth: Bool { self == .both }

    public var title: String {
        switch self {
        case .codeOnly: return "Nur Code"
        case .breathOnly: return "Nur Atempause"
        case .either: return "Code oder Atempause"
        case .both: return "Atempause und Code"
        }
    }

    public var explanation: String {
        switch self {
        case .codeOnly:
            return "Du gibst deinen Code ein und die Sperre oeffnet sich sofort."
        case .breathOnly:
            return "Kein Code. Du atmest die eingestellte Zeit lang durch, danach oeffnet sich die Sperre."
        case .either:
            return "Du entscheidest in dem Moment: Code eingeben oder die Atempause abwarten."
        case .both:
            return "Erst die volle Atempause, danach zusaetzlich der Code. Die groesste Huerde."
        }
    }
}

// MARK: - Wochentag

public enum Weekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public var id: Int { rawValue }

    public var shortName: String {
        switch self {
        case .monday: return "Mo"
        case .tuesday: return "Di"
        case .wednesday: return "Mi"
        case .thursday: return "Do"
        case .friday: return "Fr"
        case .saturday: return "Sa"
        case .sunday: return "So"
        }
    }

    /// Montag zuerst — so wie der Kalender im deutschsprachigen Raum laeuft.
    public static let displayOrder: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
    ]
}

// MARK: - Tageszeit

/// Uhrzeit ohne Datum, als Minuten seit Mitternacht.
public struct TimeOfDay: Codable, Equatable, Comparable, Sendable {
    public var minutes: Int

    public init(minutes: Int) {
        self.minutes = ((minutes % 1440) + 1440) % 1440
    }

    public init(hour: Int, minute: Int) {
        self.init(minutes: hour * 60 + minute)
    }

    public var hour: Int { minutes / 60 }
    public var minute: Int { minutes % 60 }

    public var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutes < rhs.minutes
    }

    /// Uhrzeit aus einem `Date` in der aktuellen Zeitzone.
    public static func from(_ date: Date, calendar: Calendar = .current) -> TimeOfDay {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// `Date` von heute mit dieser Uhrzeit — fuer die Anzeige in `DatePicker`.
    public func asDate(calendar: Calendar = .current) -> Date {
        calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: Date()
        ) ?? Date()
    }
}

// MARK: - Zeitfenster

/// Ein Sperrfenster, z. B. „22:00 bis 07:00, Mo–Fr“.
public struct BlockWindow: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var start: TimeOfDay
    public var end: TimeOfDay
    public var weekdays: Set<Weekday>

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        start: TimeOfDay,
        end: TimeOfDay,
        weekdays: Set<Weekday> = Set(Weekday.allCases)
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.start = start
        self.end = end
        self.weekdays = weekdays
    }

    /// Laeuft das Fenster ueber Mitternacht hinweg?
    public var crossesMidnight: Bool { end <= start }

    /// Ist das Fenster zum gegebenen Zeitpunkt aktiv?
    ///
    /// Bei einem Fenster ueber Mitternacht zaehlt der Wochentag, an dem das
    /// Fenster *begonnen* hat. „Mo 22:00–07:00“ sperrt also bis Dienstag frueh.
    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, !weekdays.isEmpty else { return false }

        let now = TimeOfDay.from(date, calendar: calendar)
        let todayIndex = calendar.component(.weekday, from: date)
        guard let today = Weekday(rawValue: todayIndex) else { return false }

        if !crossesMidnight {
            return weekdays.contains(today) && now >= start && now < end
        }

        // Abendteil: heute nach Start — der Starttag muss ausgewaehlt sein.
        if now >= start {
            return weekdays.contains(today)
        }
        // Morgenteil: heute vor Ende — der Starttag war gestern.
        if now < end {
            let yesterdayIndex = todayIndex == 1 ? 7 : todayIndex - 1
            guard let yesterday = Weekday(rawValue: yesterdayIndex) else { return false }
            return weekdays.contains(yesterday)
        }
        return false
    }

    public var weekdaySummary: String {
        if weekdays.count == 7 { return "Taeglich" }
        if weekdays == [.monday, .tuesday, .wednesday, .thursday, .friday] { return "Mo–Fr" }
        if weekdays == [.saturday, .sunday] { return "Wochenende" }
        if weekdays.isEmpty { return "Nie" }
        return Weekday.displayOrder
            .filter { weekdays.contains($0) }
            .map(\.shortName)
            .joined(separator: " ")
    }
}

// MARK: - Einstellungen

public struct BlockSettings: Codable, Equatable, Sendable {
    /// Hauptschalter. Aus = nichts wird gesperrt.
    public var isArmed: Bool

    /// Sperrfenster nach Uhrzeit.
    public var windows: [BlockWindow]

    /// Tagesbudget: nach so vielen Minuten Nutzung sperren.
    public var usageLimitEnabled: Bool
    public var usageLimitMinutes: Int

    /// Wie die Sperre umgangen werden darf.
    public var unlockMethod: UnlockMethod

    /// Dauer der Atempause in Sekunden.
    public var breathSeconds: Int

    /// Wie lange nach erfolgreichem Entsperren offen bleibt — in Minuten
    /// tatsaechlicher Nutzung der gesperrten Apps.
    public var unlockMinutes: Int

    /// Maximale Entsperrungen pro Tag. 0 = unbegrenzt.
    public var maxUnlocksPerDay: Int

    /// Verhindert das Loeschen der App, solange eine Sperre aktiv ist.
    public var preventAppDeletion: Bool

    /// Text, den du dir selbst auf den Sperrbildschirm schreibst.
    public var shieldMessage: String

    public static let `default` = BlockSettings(
        isArmed: false,
        windows: [
            BlockWindow(
                name: "Nachtruhe",
                start: TimeOfDay(hour: 22, minute: 0),
                end: TimeOfDay(hour: 7, minute: 0)
            )
        ],
        usageLimitEnabled: false,
        usageLimitMinutes: 60,
        unlockMethod: .either,
        breathSeconds: 60,
        unlockMinutes: 10,
        maxUnlocksPerDay: 0,
        preventAppDeletion: false,
        shieldMessage: "Kurz innehalten. Willst du das jetzt wirklich?"
    )

    public init(
        isArmed: Bool,
        windows: [BlockWindow],
        usageLimitEnabled: Bool,
        usageLimitMinutes: Int,
        unlockMethod: UnlockMethod,
        breathSeconds: Int,
        unlockMinutes: Int,
        maxUnlocksPerDay: Int,
        preventAppDeletion: Bool,
        shieldMessage: String
    ) {
        self.isArmed = isArmed
        self.windows = windows
        self.usageLimitEnabled = usageLimitEnabled
        self.usageLimitMinutes = usageLimitMinutes
        self.unlockMethod = unlockMethod
        self.breathSeconds = breathSeconds
        self.unlockMinutes = unlockMinutes
        self.maxUnlocksPerDay = maxUnlocksPerDay
        self.preventAppDeletion = preventAppDeletion
        self.shieldMessage = shieldMessage
    }

    /// Ist gerade ein Zeitfenster aktiv?
    public func activeWindow(at date: Date = Date()) -> BlockWindow? {
        windows.first { $0.isActive(at: date) }
    }

    /// Das naechste Fenster, das beginnt — fuer die Anzeige „sperrt in …“.
    public func nextWindowStart(after date: Date = Date(), calendar: Calendar = .current) -> Date? {
        let enabled = windows.filter { $0.isEnabled && !$0.weekdays.isEmpty }
        guard !enabled.isEmpty else { return nil }

        // Bis zu acht Tage vorausschauen, damit auch ein einzelner
        // Wochentag sicher gefunden wird.
        for dayOffset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let weekdayIndex = calendar.component(.weekday, from: day)
            guard let weekday = Weekday(rawValue: weekdayIndex) else { continue }

            let candidates = enabled
                .filter { $0.weekdays.contains(weekday) }
                .compactMap { window -> Date? in
                    calendar.date(
                        bySettingHour: window.start.hour,
                        minute: window.start.minute,
                        second: 0,
                        of: day
                    )
                }
                .filter { $0 > date }
                .sorted()

            if let soonest = candidates.first { return soonest }
        }
        return nil
    }
}

// MARK: - Laufzeitzustand

/// Alles, was sich waehrend des Betriebs aendert. Getrennt von den
/// Einstellungen, damit ein Schreibvorgang aus einer Extension nicht
/// versehentlich deine Konfiguration ueberschreibt.
public struct RuntimeState: Codable, Equatable, Sendable {
    /// Bis wann die Sperre ausgesetzt ist. `nil` = keine Entsperrung aktiv.
    public var unlockedUntil: Date?

    /// Tag (als `yyyy-MM-dd`), an dem das Nutzungsbudget gerissen wurde.
    public var budgetExceededOn: String?

    /// Tag der gezaehlten Entsperrungen und deren Anzahl.
    public var unlockCountDay: String?
    public var unlockCount: Int

    /// Zeitpunkt der letzten Anfrage vom Sperrbildschirm — die Extension
    /// setzt das, die App zeigt daraufhin direkt den Entsperr-Dialog.
    public var pendingRequestAt: Date?

    /// Fehlversuche bei der Code-Eingabe und Sperre bis.
    public var failedAttempts: Int
    public var lockoutUntil: Date?

    /// Statistik, rein informativ.
    public var totalUnlocks: Int
    public var totalBreathsCompleted: Int
    public var totalAborted: Int

    public static let empty = RuntimeState(
        unlockedUntil: nil,
        budgetExceededOn: nil,
        unlockCountDay: nil,
        unlockCount: 0,
        pendingRequestAt: nil,
        failedAttempts: 0,
        lockoutUntil: nil,
        totalUnlocks: 0,
        totalBreathsCompleted: 0,
        totalAborted: 0
    )

    public init(
        unlockedUntil: Date?,
        budgetExceededOn: String?,
        unlockCountDay: String?,
        unlockCount: Int,
        pendingRequestAt: Date?,
        failedAttempts: Int,
        lockoutUntil: Date?,
        totalUnlocks: Int,
        totalBreathsCompleted: Int,
        totalAborted: Int
    ) {
        self.unlockedUntil = unlockedUntil
        self.budgetExceededOn = budgetExceededOn
        self.unlockCountDay = unlockCountDay
        self.unlockCount = unlockCount
        self.pendingRequestAt = pendingRequestAt
        self.failedAttempts = failedAttempts
        self.lockoutUntil = lockoutUntil
        self.totalUnlocks = totalUnlocks
        self.totalBreathsCompleted = totalBreathsCompleted
        self.totalAborted = totalAborted
    }

    public func isUnlocked(at date: Date = Date()) -> Bool {
        guard let until = unlockedUntil else { return false }
        return until > date
    }

    public func isBudgetExceeded(at date: Date = Date()) -> Bool {
        budgetExceededOn == DayKey.of(date)
    }

    public func unlocksUsed(at date: Date = Date()) -> Int {
        unlockCountDay == DayKey.of(date) ? unlockCount : 0
    }
}

/// Tagesschluessel in lokaler Zeit — Basis fuer alle Tageszaehler.
public enum DayKey {
    public static func of(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0
        )
    }
}
