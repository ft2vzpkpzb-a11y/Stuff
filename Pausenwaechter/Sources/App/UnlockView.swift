import SwiftUI

/// Der Weg durch die Sperre. Je nach Einstellung: Code, Atempause,
/// beides zur Wahl oder beides hintereinander.
struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .choosing
    @State private var grantedUntil: Date?
    @State private var errorMessage: String?

    enum Stage: Equatable {
        case choosing
        case breathing
        case code
        case done
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .choosing: chooser
                case .breathing: breathing
                case .code: codeEntry
                case .done: success
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(stage == .done ? "Freigegeben" : "Entsperren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if stage == .code, model.settings.unlockMethod == .either {
                        // Hier ist die Atempause noch eine echte Alternative.
                        Button("Zurueck") { stage = .choosing }
                    } else if stage != .breathing {
                        Button(stage == .done ? "Fertig" : "Abbrechen") { dismiss() }
                    }
                }
            }
            .alert(
                "Entsperren nicht moeglich",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("Verstanden") { dismiss() }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(stage == .breathing)
        .onAppear(perform: pickInitialStage)
    }

    // MARK: - Einstieg

    private func pickInitialStage() {
        switch model.settings.unlockMethod {
        case .codeOnly: stage = .code
        case .breathOnly, .both: stage = .breathing
        case .either: stage = .choosing
        }
    }

    // MARK: - Auswahl

    private var chooser: some View {
        VStack(spacing: 20) {
            header(
                icon: "arrow.triangle.branch",
                title: "Wie moechtest du weiter?",
                subtitle: "Beide Wege fuehren zum selben Ziel. Der eine kostet dich einen Code, "
                    + "der andere ein paar ruhige Atemzuege."
            )

            Spacer(minLength: 0)

            Button {
                stage = .breathing
            } label: {
                choiceCard(
                    icon: "wind",
                    tint: Theme.calm,
                    title: "Durchatmen",
                    detail: "\(formatSeconds(model.settings.breathSeconds)) in Ruhe, dann geht es weiter."
                )
            }
            .buttonStyle(.plain)

            Button {
                stage = .code
            } label: {
                choiceCard(
                    icon: "number.square",
                    tint: Theme.accent,
                    title: "Code eingeben",
                    detail: Passcode.isSet ? "Sofortiger Zugriff." : "Noch kein Code gesetzt."
                )
            }
            .buttonStyle(.plain)
            .disabled(!Passcode.isSet)
            .opacity(Passcode.isSet ? 1 : 0.5)

            Spacer(minLength: 0)
        }
    }

    private func choiceCard(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Atempause

    private var breathing: some View {
        BreathingView(
            totalSeconds: model.settings.breathSeconds,
            onFinished: {
                model.recordCompletedBreath()
                if model.settings.unlockMethod.requiresBoth {
                    stage = .code
                } else {
                    complete()
                }
            },
            onAborted: {
                model.recordAbort()
                dismiss()
            }
        )
    }

    // MARK: - Code

    private var codeEntry: some View {
        CodeEntryView(
            note: model.settings.unlockMethod.requiresBoth
                ? "Die Atempause liegt hinter dir. Jetzt noch der Code."
                : nil,
            onSuccess: complete
        )
    }

    // MARK: - Erfolg

    private var success: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.open.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.calm)
            Text("Offen")
                .font(.title2.weight(.semibold))

            Text("Du hast \(formatMinutes(model.settings.unlockMinutes)) Nutzungszeit. "
                 + "Danach greift die Sperre wieder von selbst.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let until = grantedUntil {
                Text("Spaetestens um \(until.formatted(date: .omitted, time: .shortened)).")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Fertig").primaryButtonStyle(tint: Theme.calm)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Abschluss

    private func complete() {
        do {
            grantedUntil = try model.grantUnlock()
            stage = .done
        } catch {
            // Praktisch nur das Tageslimit. Der Hinweis erscheint als
            // Meldung, danach schliesst sich das Fenster.
            errorMessage = error.localizedDescription
        }
    }

    private func header(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.accent)
            Text(title).font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Code-Eingabe

private struct CodeEntryView: View {
    let note: String?
    let onSuccess: () -> Void

    @State private var entered = ""
    @State private var message: String?
    @State private var shake = 0
    @State private var lockoutRemaining: TimeInterval = 0

    /// Siehe `BreathingView`: als `@State` ueberlebt der Timer den Neuaufbau
    /// der Struktur.
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let maxDigits = 12

    private var isLockedOut: Bool { lockoutRemaining > 0 }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Image(systemName: isLockedOut ? "hourglass" : "lock.fill")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(isLockedOut ? Theme.warn : Theme.accent)
                Text(isLockedOut ? "Kurz gesperrt" : "Dein Code")
                    .font(.title3.weight(.semibold))
                if let note, !isLockedOut {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if isLockedOut {
                    Text("Zu viele Fehlversuche. Noch \(Int(lockoutRemaining.rounded())) Sekunden.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warn)
                }
            }

            dots
                .modifier(ShakeEffect(travel: 8, shakes: 3, animatableData: CGFloat(shake)))

            if let message {
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.danger)
            }

            Spacer(minLength: 0)

            Keypad(
                onDigit: { digit in
                    guard !isLockedOut, entered.count < maxDigits else { return }
                    entered.append(digit)
                    message = nil
                },
                onDelete: {
                    guard !entered.isEmpty else { return }
                    entered.removeLast()
                },
                onSubmit: submit,
                submitEnabled: entered.count >= 4 && !isLockedOut
            )
        }
        .onAppear { lockoutRemaining = Passcode.lockoutRemaining() }
        .onReceive(tick) { _ in
            lockoutRemaining = Passcode.lockoutRemaining()
        }
    }

    private var dots: some View {
        HStack(spacing: 12) {
            ForEach(0..<max(4, entered.count), id: \.self) { index in
                Circle()
                    .fill(index < entered.count ? Theme.accent : Color(.tertiarySystemFill))
                    .frame(width: 14, height: 14)
            }
        }
        .frame(height: 20)
    }

    /// Bewusst kein automatisches Pruefen bei vier Ziffern: der Code darf
    /// laenger sein, also loest erst der Haken die Pruefung aus.
    private func submit() {
        guard !isLockedOut else { return }
        guard Passcode.isSet else {
            message = "Es ist kein Code hinterlegt."
            return
        }

        if Passcode.verify(entered) {
            Passcode.registerSuccess()
            onSuccess()
            return
        }

        Passcode.registerFailure()
        lockoutRemaining = Passcode.lockoutRemaining()
        entered = ""
        withAnimation(.default) { shake += 1 }

        let left = Passcode.remainingAttempts
        message = isLockedOut
            ? "Zu viele Fehlversuche."
            : "Falscher Code. Noch \(left) Versuch\(left == 1 ? "" : "e")."
    }
}

// MARK: - Ziffernfeld

private struct Keypad: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void
    let submitEnabled: Bool

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { digit in
                        key(digit) { onDigit(digit) }
                    }
                }
            }
            HStack(spacing: 12) {
                iconKey("delete.left", action: onDelete)
                key("0") { onDigit("0") }
                iconKey("checkmark", action: onSubmit, tint: Theme.calm, enabled: submitEnabled)
            }
        }
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.weight(.regular))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func iconKey(
        _ systemName: String,
        action: @escaping () -> Void,
        tint: Color = .secondary,
        enabled: Bool = true
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(enabled ? tint : Color.secondary.opacity(0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Ruettel-Effekt

private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var shakes: CGFloat
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = travel * sin(animatableData * .pi * shakes)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
