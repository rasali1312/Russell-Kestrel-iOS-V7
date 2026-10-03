import SwiftUI

struct PlaybackView: View {
    @EnvironmentObject var settings: SettingsStore
    @Binding var selectedChannel: Int
    @State private var date = Date()
    @State private var showingArchive = false
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Channel", selection: $selectedChannel) {
                    ForEach(1...min(settings.config.maxChannels, 32), id: \.self) { Text("CAM \($0)").tag($0) }
                }
                .pickerStyle(.menu)
                Spacer()
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }
            .padding(.horizontal)
            if showingArchive, let url = settings.archiveURL(channel: selectedChannel, date: date) {
                KestrelWebView(url: url)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "play.rectangle").font(.system(size: 44))
                    Text("Kestrel DVR archive")
                        .font(.headline)
                    Text("Choose a camera and date, then open the DVR playback interface. Recordings remain on the Kestrel HDD.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Open DVR Playback") { showingArchive = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding(30)
                Spacer()
            }
        }
        .padding(.top)
        .navigationTitle("Playback")
    }
}
