import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Group {
            if app.client == nil {
                LoginView()
            } else {
                MainTabs()
            }
        }
        .background(Color.kBackground.ignoresSafeArea())
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            AlbumsView()
                .tabItem { Label("Albums", systemImage: "square.stack") }
            SearchView()
                .tabItem { Label("Recherche", systemImage: "magnifyingglass") }
        }
    }
}
