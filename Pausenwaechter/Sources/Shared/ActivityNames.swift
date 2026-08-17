import Foundation

#if canImport(DeviceActivity)
import DeviceActivity
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(DeviceActivity)
public extension DeviceActivityName {
    /// Weckt die Extension am Anfang und Ende jedes Sperrfensters.
    /// Fenster ueber Mitternacht werden in zwei Haelften registriert.
    static func window(_ index: Int, half: Int) -> DeviceActivityName {
        DeviceActivityName("window.\(index).\(half)")
    }

    /// Laeuft den ganzen Tag und traegt den Schwellwert fuer das Tagesbudget.
    static let usageBudget = DeviceActivityName("usage.budget")

    /// Laeuft nur waehrend einer aktiven Entsperrung.
    static let unlockWindow = DeviceActivityName("unlock.window")
}

public extension DeviceActivityEvent.Name {
    /// Feuert, wenn das Tagesbudget aufgebraucht ist.
    static let budgetReached = DeviceActivityEvent.Name("budget.reached")

    /// Feuert, wenn die freigegebene Nutzungszeit verbraucht ist.
    static let unlockElapsed = DeviceActivityEvent.Name("unlock.elapsed")
}
#endif

#if canImport(ManagedSettings)
public extension ManagedSettingsStore.Name {
    /// Eigener benannter Store — beruehrt keine anderen Screen-Time-Regeln,
    /// die auf dem Geraet gesetzt sind.
    static let pausenwaechter = ManagedSettingsStore.Name("pausenwaechter")
}
#endif
