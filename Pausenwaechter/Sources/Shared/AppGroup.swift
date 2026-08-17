import Foundation

/// Gemeinsamer Speicher zwischen Haupt-App und den drei App-Extensions.
///
/// Alle vier Targets tragen dieselbe App-Group in ihren Entitlements. Nur so
/// koennen die Extensions (die in eigenen Prozessen laufen und vom System
/// gestartet werden) die Einstellungen lesen, die du in der App gesetzt hast.
public enum AppGroup {
    /// Muss identisch sein mit dem Wert in allen `*.entitlements`-Dateien.
    /// Wenn du die Bundle-ID aenderst, hier ebenfalls anpassen.
    public static let identifier = "group.dev.pausenwaechter"

    public static var defaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            // Tritt nur auf, wenn die App-Group in den Entitlements fehlt.
            // Fallback verhindert einen Absturz der Extension.
            return .standard
        }
        return defaults
    }
}

/// Schluessel im geteilten UserDefaults-Container.
public enum StorageKey {
    public static let settings = "settings.v1"
    public static let runtime = "runtime.v1"
    public static let selection = "selection.v1"
}
