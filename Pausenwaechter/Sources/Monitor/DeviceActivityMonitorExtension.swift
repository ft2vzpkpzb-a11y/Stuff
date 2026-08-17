import DeviceActivity
import Foundation

/// Wird vom System aufgeweckt, wenn ein Zeitplan beginnt oder endet oder
/// ein Nutzungsschwellwert erreicht ist.
///
/// Die Extension trifft selbst keine Entscheidungen. Sie meldet das Ereignis
/// an die `BlockingEngine`, die den Sollzustand neu berechnet. So kann ein
/// verpasstes Ereignis nichts dauerhaft verstellen.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        if activity == .usageBudget {
            // Neuer Tag: Budget und Entsperrzaehler zuruecksetzen.
            BlockingEngine.handleDayRollover()
            return
        }
        BlockingEngine.refresh()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        if activity == .unlockWindow {
            BlockingEngine.handleUnlockExpired()
            return
        }
        BlockingEngine.refresh()
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        switch event {
        case .budgetReached:
            BlockingEngine.handleBudgetReached()
        case .unlockElapsed:
            BlockingEngine.handleUnlockExpired()
        default:
            BlockingEngine.refresh()
        }
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        // Platz fuer eine Vorwarnung („in 5 Minuten wird gesperrt“).
        // Bewusst leer gelassen, damit ohne Mitteilungsrecht nichts scheitert.
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }
}
