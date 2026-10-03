import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var selected = 1
    @State private var showSettings = false
    var body: some View {
        NavigationStack {
            TabView {
                LiveView(selectedChannel: $selected)
                    .tabItem { Label("Live", systemImage: "video") }
                PlaybackView(selectedChannel: $selected)
                    .tabItem { Label("Playback", systemImage: "clock.arrow.circlepath") }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
        }
    }
}
