import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: BlockWindow?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.settings.windows) { window in
                        Button {
                            editing = window
                        } label: {
                            WindowRow(window: window)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        model.settings.windows.remove(atOffsets: offsets)
                    }

                    Button {
                        let new = BlockWindow(
                            name: "Neues Fenster",
                            start: TimeOfDay(hour: 20, minute: 0),
                            end: TimeOfDay(hour: 22, minute: 0)
                        )
                        model.settings.windows.append(new)
                        editing = new
                    } label: {
                        Label("Zeitfenster hinzufuegen", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Sperrfenster nach Uhrzeit")
                } footer: {
                    Text("In diesen Zeitraeumen sind die gewaehlten Apps gesperrt. "
                         + "Ein Fenster darf ueber Mitternacht laufen; der Wochentag zaehlt dann "
                         + "fuer den Abend, an dem es beginnt. Mindestlaenge: 15 Minuten.")
                }

                Section {
                    Toggle("Tagesbudget verwenden", isOn: Binding(
                        get: { model.settings.usageLimitEnabled },
                        set: { model.settings.usageLimitEnabled = $0 }
                    ))

                    if model.settings.usageLimitEnabled {
                        Stepper(
                            value: Binding(
                                get: { model.settings.usageLimitMinutes },
                                set: { model.settings.usageLimitMinutes = $0 }
                            ),
                            in: 5...480,
                            step: 5
                        ) {
                            HStack {
                                Text("Erlaubt pro Tag")
                                Spacer()
                                Text(formatMinutes(model.settings.usageLimitMinutes))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }

                        if model.runtime.isBudgetExceeded() {
                            Label("Heute bereits aufgebraucht", systemImage: "exclamationmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.warn)
                        }
                    }
                } header: {
                    Text("Sperre nach Nutzungsdauer")
                } footer: {
                    Text("Unabhaengig von der Uhrzeit: Sobald du die gewaehlten Apps heute "
                         + "insgesamt so lange benutzt hast, sind sie fuer den Rest des Tages "
                         + "gesperrt. Der Zaehler beginnt um Mitternacht neu.")
                }
            }
            .navigationTitle("Zeiten")
            .toolbar { EditButton() }
            .sheet(item: $editing) { window in
                WindowEditor(window: window) { updated in
                    if let index = model.settings.windows.firstIndex(where: { $0.id == updated.id }) {
                        model.settings.windows[index] = updated
                    }
                }
            }
        }
    }
}

// MARK: - Zeile

private struct WindowRow: View {
    let window: BlockWindow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: window.isEnabled ? "clock.fill" : "clock")
                .foregroundStyle(window.isEnabled ? Theme.accent : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(window.name)
                    .font(.body.weight(.medium))
                Text("\(window.start.formatted)–\(window.end.formatted) · \(window.weekdaySummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if window.isActive(at: Date()) {
                Text("laeuft")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.danger.opacity(0.18), in: Capsule())
                    .foregroundStyle(Theme.danger)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .opacity(window.isEnabled ? 1 : 0.55)
    }
}

// MARK: - Editor

private struct WindowEditor: View {
    @State private var draft: BlockWindow
    @Environment(\.dismiss) private var dismiss
    let onSave: (BlockWindow) -> Void

    init(window: BlockWindow, onSave: @escaping (BlockWindow) -> Void) {
        _draft = State(initialValue: window)
        self.onSave = onSave
    }

    private var lengthMinutes: Int {
        let delta = draft.end.minutes - draft.start.minutes
        return delta > 0 ? delta : delta + 1440
    }

    private var isTooShort: Bool { lengthMinutes < 15 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                    Toggle("Aktiv", isOn: $draft.isEnabled)
                }

                Section("Zeitraum") {
                    DatePicker(
                        "Von",
                        selection: Binding(
                            get: { draft.start.asDate() },
                            set: { draft.start = TimeOfDay.from($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Bis",
                        selection: Binding(
                            get: { draft.end.asDate() },
                            set: { draft.end = TimeOfDay.from($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    HStack {
                        Text("Laenge")
                        Spacer()
                        Text(formatMinutes(lengthMinutes))
                            .foregroundStyle(isTooShort ? Theme.danger : .secondary)
                            .monospacedDigit()
                    }

                    if draft.crossesMidnight {
                        Label("Laeuft ueber Mitternacht", systemImage: "moon.stars")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if isTooShort {
                        Label("iOS verlangt mindestens 15 Minuten.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                    }
                }

                Section("Wochentage") {
                    WeekdayPicker(selection: $draft.weekdays)
                    HStack(spacing: 10) {
                        quickButton("Alle", [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])
                        quickButton("Mo–Fr", [.monday, .tuesday, .wednesday, .thursday, .friday])
                        quickButton("Wochenende", [.saturday, .sunday])
                    }
                }
            }
            .navigationTitle("Zeitfenster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(isTooShort || draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func quickButton(_ title: String, _ days: Set<Weekday>) -> some View {
        Button(title) { draft.weekdays = days }
            .font(.caption.weight(.medium))
            .buttonStyle(.bordered)
    }
}

// MARK: - Wochentagsauswahl

private struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.displayOrder) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(day.shortName)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isOn ? Theme.accent : Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
