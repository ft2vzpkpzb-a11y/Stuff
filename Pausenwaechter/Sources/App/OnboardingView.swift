import SwiftUI
import FamilyControls

/// Fuehrt einmalig durch die vier Schritte, ohne die nichts funktioniert.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var page = 0
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                permission.tag(1)
                apps.tag(2)
                method.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: advance) {
                Text(page == 3 ? "Los geht's" : "Weiter")
                    .primaryButtonStyle(tint: Theme.accent, enabled: canAdvance)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .familyActivityPicker(isPresented: $showPicker, selection: $model.selection)
    }

    private var canAdvance: Bool {
        switch page {
        case 1: return model.authorization == .approved
        case 2: return model.hasSelection
        default: return true
        }
    }

    private func advance() {
        if page < 3 {
            withAnimation { page += 1 }
        } else {
            model.hasCompletedOnboarding = true
        }
    }

    // MARK: - Seiten

    private var welcome: some View {
        makePage(
            icon: "moon.stars.fill",
            tint: Theme.accent,
            title: "Pausenwaechter",
            body: "Du legst fest, welche Apps ab wann gesperrt sind. "
                + "Wenn du trotzdem hinein willst, kostet es dich entweder deinen Code "
                + "oder ein paar ruhige Atemzuege.\n\n"
                + "Kein Konto, keine Cloud, keine Daten nach aussen. Alles bleibt auf diesem Geraet."
        )
    }

    private var permission: some View {
        makePage(
            icon: "hand.raised.fill",
            tint: Theme.warn,
            title: "Bildschirmzeit freigeben",
            body: "Apps sperren darf auf dem iPhone nur, wer die Bildschirmzeit-Freigabe hat. "
                + "Der Pausenwaechter erfaehrt dadurch nicht, was du tust — er darf nur die "
                + "Apps sperren, die du gleich selbst auswaehlst."
        ) {
            VStack(spacing: 12) {
                if model.authorization == .approved {
                    Label("Freigabe erteilt", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.calm)
                        .font(.subheadline.weight(.medium))
                } else {
                    Button {
                        Task { await model.requestAuthorization() }
                    } label: {
                        Text("Freigabe erteilen")
                            .primaryButtonStyle(tint: Theme.warn)
                    }
                    .buttonStyle(.plain)
                }
                if let error = model.authorizationError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var apps: some View {
        makePage(
            icon: "square.grid.2x2.fill",
            tint: Theme.accent,
            title: "Apps auswaehlen",
            body: "Waehle die Apps, die dich am haeufigsten wegziehen. "
                + "Drei bis fuenf reichen meist — je enger die Auswahl, desto eher haeltst du sie durch."
        ) {
            VStack(spacing: 12) {
                Button {
                    showPicker = true
                } label: {
                    Text(model.hasSelection ? "Auswahl aendern" : "Apps auswaehlen")
                        .primaryButtonStyle(tint: Theme.accent)
                }
                .buttonStyle(.plain)

                if model.hasSelection {
                    Label("\(model.selectionCount) ausgewaehlt", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.calm)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private var method: some View {
        makePage(
            icon: "wind",
            tint: Theme.calm,
            title: "Wie du wieder hineinkommst",
            body: "Das kannst du spaeter jederzeit aendern. "
                + "Die Atempause ist die sanftere Huerde, der Code die haertere."
        ) {
            VStack(spacing: 14) {
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
                    .multilineTextAlignment(.center)

                Text("Standard: Sperrfenster 22:00–07:00 taeglich, eine Minute Atempause, "
                     + "danach zehn Minuten Nutzung frei.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Bausteine

    private func makePage(
        icon: String,
        tint: Color,
        title: String,
        body text: String
    ) -> some View {
        makePage(icon: icon, tint: tint, title: title, body: text) { EmptyView() }
    }

    private func makePage<Extra: View>(
        icon: String,
        tint: Color,
        title: String,
        body text: String,
        @ViewBuilder extra: () -> Extra
    ) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 40)
                Image(systemName: icon)
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                extra()
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 28)
        }
    }
}
