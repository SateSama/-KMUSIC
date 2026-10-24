import SwiftUI

@main
struct KMUSICApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var player = PlayerManager()

    init() {
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .tint(Color.kPrimary)
        }
    }
}
