import SwiftUI

@main
@MainActor
struct PapiersProApp: App {
    @State private var store = DocumentStore()
    @State private var subscriptions = SubscriptionManager()
    @AppStorage("appearance") private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(subscriptions)
                .preferredColorScheme(appearance.colorScheme)
                .environment(\.locale, Locale(identifier: "fr_FR"))
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Automatique"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
