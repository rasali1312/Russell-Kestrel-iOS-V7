import SwiftUI

@main
struct RussellKestrelApp: App {
    @StateObject private var settings = SettingsStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
    }
}
