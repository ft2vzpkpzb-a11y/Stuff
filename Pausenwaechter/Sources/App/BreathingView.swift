import SwiftUI

/// Die Atempause. Ein Kreis, der sich hebt und senkt, und ein Zaehler.
///
/// Die Pause laeuft nur, solange die App im Vordergrund ist. Wer
/// zwischendurch wegwischt, faengt von vorn an — sonst waere es blosses
/// Warten und keine Pause.
struct BreathingView: View {
    let totalSeconds: Int
    let onFinished: () -> Void
    let onAborted: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var remaining: Int
    @State private var phase: BreathPhase = .inhale
    @State private var phaseRemaining: Int
    @State private var didRestart = false

    /// Vier Sekunden ein, sechs Sekunden aus — laengeres Ausatmen beruhigt.
    private static let inhaleSeconds = 4
    private static let exhaleSeconds = 6

    /// Muss `@State` sein: SwiftUI baut die Struktur bei jeder Aktualisierung
    /// neu auf. Als gewoehnliche Eigenschaft entstuende jedes Mal ein frischer
    /// Timer, der nie bis zur ersten Sekunde kaeme.
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum BreathPhase {
        case inhale, exhale

        var label: String {
            switch self {
            case .inhale: return "Einatmen"
            case .exhale: return "Ausatmen"
            }
        }
    }

    init(totalSeconds: Int, onFinished: @escaping () -> Void, onAborted: @escaping () -> Void) {
        self.totalSeconds = totalSeconds
        self.onFinished = onFinished
        self.onAborted = onAborted
        _remaining = State(initialValue: totalSeconds)
        _phaseRemaining = State(initialValue: Self.inhaleSeconds)
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 1 }
        return Double(totalSeconds - remaining) / Double(totalSeconds)
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            circle

            VStack(spacing: 6) {
                Text(phase.label)
                    .font(.title3.weight(.medium))
                    .contentTransition(.opacity)
                Text(formatSeconds(remaining) + " verbleiben")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if didRestart {
                Label("Du hast die App verlassen — die Pause beginnt von vorn.",
                      systemImage: "arrow.counterclockwise")
                    .font(.footnote)
                    .foregroundStyle(Theme.warn)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer(minLength: 0)

            Button {
                onAborted()
            } label: {
                Text("Doch nicht")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .onReceive(tick) { _ in step() }
        .onChange(of: scenePhase) { newPhase in
            // Zurueck aus dem Hintergrund: Pause zuruecksetzen.
            if newPhase == .active, remaining < totalSeconds {
                withAnimation { restart() }
            }
        }
    }

    private var circle: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Theme.calm,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.calm.opacity(0.55), Theme.calm.opacity(0.08)],
                        center: .center,
                        startRadius: 4,
                        endRadius: 130
                    )
                )
                .scaleEffect(phase == .inhale ? 0.94 : 0.52)
                .animation(
                    .easeInOut(duration: Double(phase == .inhale ? Self.inhaleSeconds : Self.exhaleSeconds)),
                    value: phase
                )
        }
        .frame(width: 250, height: 250)
    }

    private func step() {
        guard scenePhase == .active else { return }

        if remaining <= 1 {
            remaining = 0
            onFinished()
            return
        }
        remaining -= 1

        if phaseRemaining <= 1 {
            phase = (phase == .inhale) ? .exhale : .inhale
            phaseRemaining = (phase == .inhale) ? Self.inhaleSeconds : Self.exhaleSeconds
        } else {
            phaseRemaining -= 1
        }
    }

    private func restart() {
        didRestart = true
        remaining = totalSeconds
        phase = .inhale
        phaseRemaining = Self.inhaleSeconds
    }
}
