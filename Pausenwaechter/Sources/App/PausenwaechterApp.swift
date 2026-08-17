import SwiftUI
import FamilyControls

@main
struct PausenwaechterApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if model.hasCompletedOnboarding {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(model)
            .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                model.refreshFromForeground()
            }
        }
    }
}
