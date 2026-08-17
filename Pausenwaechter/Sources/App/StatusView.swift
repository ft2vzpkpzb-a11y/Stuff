import SwiftUI

struct StatusView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showUnlock: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusHeader
                    if model.authorization != .approved { authorizationCard }
                    if !model.setupProblems.isEmpty { setupCard }
                    armCard
                    if model.isUnlocked { unlockedCard }
                    if model.isCurrentlyBlocked { blockedCard }
                    overviewCard
                    statsCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pausenwaechter")
        }
    }

    // MARK: - Kopf

    private var statusHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(headerColor.opacity(0.16))
                    .frame(width: 128, height: 128)
                Circle()
                    .strokeBorder(headerColor.opacity(0.35), lineWidth: 2)
                    .frame(width: 128, height: 128)
                Image(systemName: headerIcon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(headerColor)
            }
            Text(headerTitle)
                .font(.title2.weight(.semibold))
            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var headerColor: Color {
        if !model.settings.isArmed { return .secondary }
        if model.isUnlocked { return Theme.warn }
        if model.isCurrentlyBlocked { return Theme.danger }
        return Theme.calm
    }

    private var headerIcon: String {
        if !model.settings.isArmed { return "shield.slash" }
        if model.isUnlocked { return "hourglass" }
        if model.isCurrentlyBlocked { return "lock.fill" }
        return "checkmark.shield.fill"
    }

    private var headerTitle: String {
        if !model.settings.isArmed { return "Nicht scharf" }
        if model.isUnlocked { return "Freigegeben" }
        if model.isCurrentlyBlocked { return "Gesperrt" }
        return "Wacht"
    }

    private var headerSubtitle: String {
        if !model.settings.isArmed {
            return "Es wird nichts gesperrt. Schalte den Waechter unten scharf."
        }
        if model.isUnlocked {
            return "Noch \(formatRemaining(model.unlockRemaining)) offen, danach greift die Sperre wieder."
        }
        switch model.blockReason {
        case .schedule(let name):
            return "Sperrfenster „\(name)“ laeuft."
        case .usageBudget:
            return "Dein Tagesbudget ist aufgebraucht."
        case .none:
            if let next = model.settings.nextWindowStart() {
                return "Naechste Sperre: \(next.formatted(date: .abbreviated, time: .shortened))."
            }
            return "Aktuell ist kein Sperrfenster aktiv."
        }
    }

    // MARK: - Karten

    private var authorizationCard: some View {
        Card(title: "Bildschirmzeit freigeben", systemImage: "hand.raised.fill", tint: Theme.warn) {
            Text("iOS erlaubt das Sperren von Apps nur mit deiner ausdruecklichen Freigabe. "
                 + "Der Pausenwaechter bekommt dadurch keine Einsicht, welche Apps du benutzt — "
                 + "nur das Recht, die von dir gewaehlten zu sperren.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let error = model.authorizationError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }

            Button {
                Task { await model.requestAuthorization() }
            } label: {
                Text("Freigabe erteilen").primaryButtonStyle(tint: Theme.warn)
            }
            .buttonStyle(.plain)
        }
    }

    private var setupCard: some View {
        Card(title: "Noch offen", systemImage: "exclamationmark.triangle.fill", tint: Theme.warn) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.setupProblems, id: \.self) { problem in
                    Label(problem, systemImage: "circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var armCard: some View {
        Card(
            title: model.settings.isArmed ? "Waechter ist scharf" : "Waechter scharf schalten",
            systemImage: "power",
            tint: model.settings.isArmed ? Theme.calm : Theme.accent
        ) {
            Toggle(isOn: Binding(
                get: { model.settings.isArmed },
                set: { model.settings.isArmed = $0 }
            )) {
                Text(model.settings.isArmed ? "Aktiv" : "Aus")
                    .font(.body.weight(.medium))
            }
            .disabled(!model.settings.isArmed && !model.canArm)

            if !model.settings.isArmed && !model.canArm {
                Text("Erledige zuerst die offenen Punkte oben.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unlockedCard: some View {
        Card(title: "Freigabe laeuft", systemImage: "hourglass", tint: Theme.warn) {
            Text(formatRemaining(model.unlockRemaining))
                .font(.system(size: 40, weight: .light, design: .rounded))
                .monospacedDigit()

            Text("Die Freigabe endet frueher, wenn du \(formatMinutes(model.settings.unlockMinutes)) "
                 + "der gesperrten Apps tatsaechlich genutzt hast.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                model.endUnlockEarly()
            } label: {
                Text("Jetzt schon wieder sperren")
                    .primaryButtonStyle(tint: Theme.calm)
            }
            .buttonStyle(.plain)
        }
    }

    private var blockedCard: some View {
        Card(title: "Sperre umgehen", systemImage: "key.fill", tint: Theme.accent) {
            Text(model.settings.unlockMethod.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if model.settings.maxUnlocksPerDay > 0 {
                let used = model.runtime.unlocksUsed()
                let left = max(0, model.settings.maxUnlocksPerDay - used)
                Text("Heute noch \(left) von \(model.settings.maxUnlocksPerDay) Entsperrungen uebrig.")
                    .font(.caption)
                    .foregroundStyle(left == 0 ? Theme.danger : .secondary)
            }

            Button {
                showUnlock = true
            } label: {
                Text("Entsperren")
                    .primaryButtonStyle(
                        tint: Theme.accent,
                        enabled: BlockingEngine.canUnlock(settings: model.settings, state: model.runtime)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!BlockingEngine.canUnlock(settings: model.settings, state: model.runtime))
        }
    }

    private var overviewCard: some View {
        Card(title: "Deine Regeln", systemImage: "list.bullet", tint: .secondary) {
            row("Gesperrte Apps", model.hasSelection ? "\(model.selectionCount) ausgewaehlt" : "keine")

            let active = model.settings.windows.filter(\.isEnabled)
            row("Zeitfenster", active.isEmpty ? "keins" : "\(active.count) aktiv")

            row(
                "Tagesbudget",
                model.settings.usageLimitEnabled
                    ? formatMinutes(model.settings.usageLimitMinutes)
                    : "aus"
            )
            row("Entsperren per", model.settings.unlockMethod.title)
            row("Atempause", formatSeconds(model.settings.breathSeconds))
            row("Freigabe danach", formatMinutes(model.settings.unlockMinutes) + " Nutzung")
        }
    }

    private var statsCard: some View {
        Card(title: "Bisher", systemImage: "chart.bar.fill", tint: .secondary) {
            row("Entsperrt", "\(model.runtime.totalUnlocks)×")
            row("Durchgeatmet", "\(model.runtime.totalBreathsCompleted)×")
            row("Doch gelassen", "\(model.runtime.totalAborted)×")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}
