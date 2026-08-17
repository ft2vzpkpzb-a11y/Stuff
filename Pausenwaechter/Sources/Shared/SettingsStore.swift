import Foundation

#if canImport(FamilyControls)
import FamilyControls
#endif

/// Lese- und Schreibzugriff auf den geteilten Container.
///
/// Wird sowohl von der App als auch von allen drei Extensions benutzt.
/// Bewusst zustandslos: jeder Zugriff liest frisch, damit ein Prozess nie
/// mit veralteten Daten des anderen arbeitet.
public enum SettingsStore {

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: Einstellungen

    public static func loadSettings() -> BlockSettings {
        guard
            let data = AppGroup.defaults.data(forKey: StorageKey.settings),
            let settings = try? decoder.decode(BlockSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    public static func saveSettings(_ settings: BlockSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        AppGroup.defaults.set(data, forKey: StorageKey.settings)
    }

    // MARK: Laufzeitzustand

    public static func loadRuntime() -> RuntimeState {
        guard
            let data = AppGroup.defaults.data(forKey: StorageKey.runtime),
            let state = try? decoder.decode(RuntimeState.self, from: data)
        else {
            return .empty
        }
        return state
    }

    public static func saveRuntime(_ state: RuntimeState) {
        guard let data = try? encoder.encode(state) else { return }
        AppGroup.defaults.set(data, forKey: StorageKey.runtime)
    }

    /// Lesen, aendern, zurueckschreiben — in einem Schritt.
    @discardableResult
    public static func mutateRuntime(_ change: (inout RuntimeState) -> Void) -> RuntimeState {
        var state = loadRuntime()
        change(&state)
        saveRuntime(state)
        return state
    }

    // MARK: App-Auswahl

    #if canImport(FamilyControls)
    /// Die vom Nutzer im `FamilyActivityPicker` gewaehlten Apps.
    ///
    /// Die Tokens darin sind undurchsichtig und nur innerhalb desselben
    /// Entwickler-Teams gueltig — deshalb funktioniert das Durchreichen
    /// per App-Group, nicht aber ein Export nach aussen.
    public static func loadSelection() -> FamilyActivitySelection {
        guard
            let data = AppGroup.defaults.data(forKey: StorageKey.selection),
            let selection = try? decoder.decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    public static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? encoder.encode(selection) else { return }
        AppGroup.defaults.set(data, forKey: StorageKey.selection)
    }

    /// Ist ueberhaupt etwas ausgewaehlt?
    public static func hasSelection() -> Bool {
        let selection = loadSelection()
        return !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }
    #endif
}
