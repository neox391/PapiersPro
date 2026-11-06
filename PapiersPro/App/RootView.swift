import SwiftUI

struct RootView: View {
    @Environment(DocumentStore.self) private var store

    var body: some View {
        Group {
            if store.profile == nil {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: store.profile == nil)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Documents", systemImage: "doc.on.doc") }
            HistoryView()
                .tabItem { Label("Historique", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
    }
}

/// Request to open the editor, either for a new document or an existing one.
struct EditorRequest: Identifiable {
    let id = UUID()
    let data: DocumentData
    let documentId: UUID?
}
