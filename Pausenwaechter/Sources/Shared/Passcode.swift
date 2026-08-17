import Foundation
import CryptoKit
import Security

/// Verwaltung des selbst gesetzten Entsperr-Codes.
///
/// Gespeichert wird nie der Code selbst, sondern ein gesalzener SHA-256-Hash.
/// Das schuetzt nicht gegen einen entschlossenen Angreifer mit Geraetezugriff —
/// es soll dich vor dir selbst schuetzen, nicht vor dem BND.
public enum Passcode {

    private static let hashKey = "passcode.hash.v1"
    private static let saltKey = "passcode.salt.v1"

    /// Maximale Fehlversuche, bevor die Eingabe gesperrt wird.
    public static let maxAttempts = 5
    /// Sperrdauer nach zu vielen Fehlversuchen.
    public static let lockoutSeconds: TimeInterval = 60

    public static var isSet: Bool {
        AppGroup.defaults.data(forKey: hashKey) != nil
    }

    public static func set(_ code: String) {
        var salt = Data(count: 32)
        let status = salt.withUnsafeMutableBytes { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, 32, base)
        }
        if status != errSecSuccess {
            // Sehr unwahrscheinlich. Fallback auf UUID-Material, damit
            // wenigstens gesalzen wird.
            salt = Data((UUID().uuidString + UUID().uuidString).utf8)
        }

        AppGroup.defaults.set(salt, forKey: saltKey)
        AppGroup.defaults.set(hash(code, salt: salt), forKey: hashKey)
    }

    public static func clear() {
        AppGroup.defaults.removeObject(forKey: hashKey)
        AppGroup.defaults.removeObject(forKey: saltKey)
    }

    public static func verify(_ code: String) -> Bool {
        guard
            let stored = AppGroup.defaults.data(forKey: hashKey),
            let salt = AppGroup.defaults.data(forKey: saltKey)
        else {
            return false
        }
        let candidate = hash(code, salt: salt)
        // Konstante Laufzeit ist hier kein echtes Thema, schadet aber nicht.
        guard candidate.count == stored.count else { return false }
        var difference: UInt8 = 0
        for (lhs, rhs) in zip(candidate, stored) { difference |= lhs ^ rhs }
        return difference == 0
    }

    private static func hash(_ code: String, salt: Data) -> Data {
        var input = salt
        input.append(Data(code.utf8))
        return Data(SHA256.hash(data: input))
    }

    // MARK: Fehlversuche

    /// Verbleibende Sperrsekunden, oder 0 wenn die Eingabe offen ist.
    public static func lockoutRemaining(at date: Date = Date()) -> TimeInterval {
        guard let until = SettingsStore.loadRuntime().lockoutUntil, until > date else { return 0 }
        return until.timeIntervalSince(date)
    }

    public static func registerFailure(at date: Date = Date()) {
        SettingsStore.mutateRuntime { state in
            state.failedAttempts += 1
            if state.failedAttempts >= maxAttempts {
                state.failedAttempts = 0
                state.lockoutUntil = date.addingTimeInterval(lockoutSeconds)
            }
        }
    }

    public static func registerSuccess() {
        SettingsStore.mutateRuntime { state in
            state.failedAttempts = 0
            state.lockoutUntil = nil
        }
    }

    public static var remainingAttempts: Int {
        max(0, maxAttempts - SettingsStore.loadRuntime().failedAttempts)
    }
}
