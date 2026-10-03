import SwiftUI
import Combine

final class SettingsStore: ObservableObject {
    @Published var config: KestrelConfiguration {
        didSet { save() }
    }
    private let key = "kestrel.config.v7"
    init() {
        if let data = UserDefaults.standard.data(forKey: key), let c = try? JSONDecoder().decode(KestrelConfiguration.self, from: data) {
            config = c
        } else { config = KestrelConfiguration() }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(config) { UserDefaults.standard.set(data, forKey: key) }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    var body: some View {
        Form {
            Section("Kestrel DVR") {
                TextField("DVR address / hostname", text: $settings.config.host)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Web port", value: $settings.config.webPort, format: .number)
                    .keyboardType(.numberPad)
                TextField("RTSP port", value: $settings.config.rtspPort, format: .number)
                    .keyboardType(.numberPad)
                TextField("Username", text: $settings.config.username)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $settings.config.password)
                Stepper("Channel capacity: \(settings.config.maxChannels)", value: $settings.config.maxChannels, in: 1...32)
            }
            Section("Current setup") {
                Text("Designed for 5 cameras now, with capacity for 16 and an upgrade path to 32+.")
                Text("Live + DVR archive are kept separate so playback can use the Kestrel web interface/HDD recordings rather than recording on the phone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
