import SwiftUI
import FamilyControls

struct AppsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card(title: "Was gesperrt wird", systemImage: "square.grid.2x2", tint: Theme.accent) {
                        if model.hasSelection {
                            summary
                        } else {
                            Text("Noch nichts ausgewaehlt. Waehle die Apps, die dich am haeufigsten "
                                 + "wegziehen — meist reichen drei bis fuenf.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            showPicker = true
                        } label: {
                            Text(model.hasSelection ? "Auswahl aendern" : "Apps auswaehlen")
                                .primaryButtonStyle(
                                    tint: Theme.accent,
                                    enabled: model.authorization == .approved
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(model.authorization != .approved)

                        if model.authorization != .approved {
                            Text("Erteile zuerst im Tab „Status“ die Bildschirmzeit-Freigabe.")
                                .font(.caption)
                                .foregroundStyle(Theme.warn)
                        }
                    }

                    if model.hasSelection {
                        Card(title: "Auswahl zuruecksetzen", systemImage: "trash", tint: .secondary) {
                            Button(role: .destructive) {
                                model.selection = FamilyActivitySelection()
                            } label: {
                                Text("Alle entfernen")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }

                    Card(title: "Warum keine Namensliste?", systemImage: "info.circle", tint: .secondary) {
                        Text("iOS gibt Apps wie dem Pausenwaechter nie die Namen oder Symbole der "
                             + "von dir gewaehlten Apps preis — die Auswahl bleibt beim System. "
                             + "Deshalb siehst du hier nur die Anzahl. Im Auswahlfenster selbst "
                             + "steht natuerlich alles im Klartext.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Apps")
            .familyActivityPicker(isPresented: $showPicker, selection: $model.selection)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            countRow("Einzelne Apps", model.selection.applicationTokens.count, "app.badge")
            countRow("Kategorien", model.selection.categoryTokens.count, "folder")
            countRow("Webseiten", model.selection.webDomainTokens.count, "globe")
        }
    }

    private func countRow(_ label: String, _ count: Int, _ icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(count > 0 ? .primary : .secondary)
            Spacer()
            Text("\(count)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(count > 0 ? Theme.accent : .secondary)
        }
    }
}
