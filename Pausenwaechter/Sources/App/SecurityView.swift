import SwiftUI

struct SecurityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showCodeSheet = false
    @State private var codeIsSet = Passcode.isSet

    /// Auswahlwerte fuer die Atempause, in Sekunden.
    private let breathChoices = [15, 30, 60, 90, 120, 180, 300, 600]
    /// Auswahlwerte fuer die Freigabedauer, in Minuten Nutzung.
    private let unlockChoices = [1, 2, 5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Methode", selection: Binding(
                        get: { model.settings.unlockMethod },
                        set: { model.settings.unlockMethod = $0 }
                    )) {
                        ForEach(UnlockMethod.allCases, id: \.self) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(model.settings.unlockMethod.explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Wie du die Sperre umgehst")
                }

                if model.settings.unlockMethod.allowsCode {
                    Section {
                        HStack {
                            Label(
                                codeIsSet ? "Code ist gesetzt" : "Kein Code gesetzt",
                                systemImage: codeIsSet ? "lock.fill" : "lock.open"
                            )
                            .foregroundStyle(codeIsSet ? Theme.calm : Theme.warn)
                            Spacer()
                        }

                        Button(codeIsSet ? "Code aendern" : "Code festlegen") {
                            showCodeSheet = true
                        }

                        if codeIsSet {
                            Button("Code loeschen", role: .destructive) {
                                Passcode.clear()
                                codeIsSet = false
                                if model.settings.unlockMethod == .codeOnly {
                                    model.settings.unlockMethod = .breathOnly
                                }
                            }
                        }
                    } header: {
                        Text("Entsperr-Code")
                    } footer: {
                        Text("Vier bis zwoelf Ziffern. Gespeichert wird nur ein gesalzener Hash, "
                             + "nie der Code selbst. Nach \(Passcode.maxAttempts) Fehlversuchen "
                             + "ist die Eingabe eine Minute lang gesperrt.\n\n"
                             + "Wenn du es dir wirklich schwer machen willst: lass jemand anderen "
                             + "den Code setzen, ohne ihn dir zu zeigen.")
                    }
                }

                if model.settings.unlockMethod.allowsBreath {
                    Section {
                        Picker("Dauer", selection: Binding(
                            get: { model.settings.breathSeconds },
                            set: { model.settings.breathSeconds = $0 }
                        )) {
                            ForEach(breathChoices, id: \.self) { seconds in
                                Text(formatSeconds(seconds)).tag(seconds)
                            }
                        }
                    } header: {
                        Text("Atempause")
                    } footer: {
                        Text("So lange musst du warten, bevor die Sperre aufgeht. Der Zaehler "
                             + "laeuft nur, solange der Pausenwaechter im Vordergrund ist — "
                             + "verlaesst du die App, beginnt die Pause von vorn. Das ist der "
                             + "Sinn der Sache: die Zeit gehoert dem Durchatmen, nicht dem Warten.")
                    }
                }

                Section {
                    Picker("Freigabe nach dem Entsperren", selection: Binding(
                        get: { model.settings.unlockMinutes },
                        set: { model.settings.unlockMinutes = $0 }
                    )) {
                        ForEach(unlockChoices, id: \.self) { minutes in
                            Text(formatMinutes(minutes)).tag(minutes)
                        }
                    }

                    Stepper(
                        value: Binding(
                            get: { model.settings.maxUnlocksPerDay },
                            set: { model.settings.maxUnlocksPerDay = $0 }
                        ),
                        in: 0...20
                    ) {
                        HStack {
                            Text("Entsperrungen pro Tag")
                            Spacer()
                            Text(model.settings.maxUnlocksPerDay == 0
                                 ? "unbegrenzt"
                                 : "\(model.settings.maxUnlocksPerDay)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Nach dem Entsperren")
                } footer: {
                    Text("Gezaehlt wird die tatsaechliche Nutzung der gesperrten Apps, nicht die "
                         + "Uhrzeit. Legst du das Handy zwischendurch weg, laeuft die Freigabe "
                         + "nicht weiter. Ein Wanduhr-Sicherheitsnetz greift spaetestens nach "
                         + "\(formatMinutes(max(15, model.settings.unlockMinutes + 10))).")
                }

                Section {
                    TextField(
                        "Dein Satz auf dem Sperrbildschirm",
                        text: Binding(
                            get: { model.settings.shieldMessage },
                            set: { model.settings.shieldMessage = String($0.prefix(160)) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                } header: {
                    Text("Erinnerung")
                } footer: {
                    Text("Dieser Text steht auf dem Bildschirm, der statt der gesperrten App "
                         + "erscheint. Schreib dir etwas, das dein spaeteres Ich erreicht.")
                }

                Section {
                    Toggle("Loeschen des Pausenwaechters verhindern", isOn: Binding(
                        get: { model.settings.preventAppDeletion },
                        set: { model.settings.preventAppDeletion = $0 }
                    ))
                } header: {
                    Text("Strenger Modus")
                } footer: {
                    Text("Solange eine Sperre aktiv ist, laesst iOS die App dann nicht loeschen. "
                         + "Zum Ausschalten schalte den Waechter unscharf.\n\n"
                         + "Wenn du dich auch daran hindern willst, hier einfach alles wieder "
                         + "umzustellen: vergib in den iOS-Einstellungen unter Bildschirmzeit "
                         + "einen Bildschirmzeit-Code und lass ihn dir von jemandem setzen.")
                }
            }
            .navigationTitle("Sperre")
            .sheet(isPresented: $showCodeSheet) {
                CodeSetupView { codeIsSet = Passcode.isSet }
            }
            .onAppear { codeIsSet = Passcode.isSet }
        }
    }
}

// MARK: - Code festlegen

private struct CodeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var first = ""
    @State private var second = ""
    @State private var error: String?
    let onDone: () -> Void

    private var isValid: Bool {
        first.count >= 4 && first.count <= 12 && first.allSatisfy(\.isNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Neuer Code", text: $first)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                    SecureField("Code wiederholen", text: $second)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                } footer: {
                    if let error {
                        Text(error).foregroundStyle(Theme.danger)
                    } else {
                        Text("Vier bis zwoelf Ziffern.")
                    }
                }
            }
            .navigationTitle("Entsperr-Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(!isValid || second.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard isValid else {
            error = "Der Code muss aus vier bis zwoelf Ziffern bestehen."
            return
        }
        guard first == second else {
            error = "Die beiden Eingaben stimmen nicht ueberein."
            return
        }
        Passcode.set(first)
        onDone()
        dismiss()
    }
}
