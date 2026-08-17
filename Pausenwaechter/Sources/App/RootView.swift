import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showUnlock = false

    var body: some View {
        TabView {
            StatusView(showUnlock: $showUnlock)
                .tabItem { Label("Status", systemImage: "shield.lefthalf.filled") }

            AppsView()
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }

            ScheduleView()
                .tabItem { Label("Zeiten", systemImage: "clock") }

            SecurityView()
                .tabItem { Label("Sperre", systemImage: "lock") }
        }
        .sheet(isPresented: $showUnlock) {
            UnlockView()
                .environmentObject(model)
        }
        .onAppear(perform: openUnlockIfRequested)
        .onChange(of: model.runtime.pendingRequestAt) { _ in
            openUnlockIfRequested()
        }
    }

    /// Kam die Anfrage vom Sperrbildschirm, springen wir direkt hinein.
    private func openUnlockIfRequested() {
        guard model.hasPendingRequest else { return }
        model.clearPendingRequest()
        showUnlock = true
    }
}
