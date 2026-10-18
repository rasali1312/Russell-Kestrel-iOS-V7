import SwiftUI

struct PlaybackView: View {
    @EnvironmentObject var settings: SettingsStore
    @Binding var selectedChannel: Int

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var startTime = Calendar.current.startOfDay(for: Date())
    @State private var endTime = Date()
    @State private var isSearching = false
    @State private var hasAutoSearched = false
    @State private var statusMessage = "Connecting to the DVR archive…"
    @State private var statusIsError = false
    @State private var records: [ArchiveRecording] = []
    @State private var selectedRecord: ArchiveRecording?

    private let archiveClient = KestrelArchiveClient()
    private var channels: [Int] { Array(1...min(max(settings.config.maxChannels, 1), 32)) }
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeStyle = .medium
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker("Recording date", selection: $selectedDate, displayedComponents: .date)
                    DatePicker("From", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("To", selection: $endTime, displayedComponents: .hourAndMinute)
                    Button {
                        Task { await searchArchive() }
                    } label: {
                        HStack {
                            if isSearching { ProgressView().tint(.white) }
                            Text(isSearching ? "Searching DVR HDD…" : "Search archive")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSearching)
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Label("DVR archive", systemImage: statusIsError ? "exclamationmark.triangle.fill" : "externaldrive.badge.timemachine")
                    .font(.headline)
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(statusIsError ? Color.red : Color.secondary)
                    .textSelection(.enabled)

                HStack {
                    Text("Cameras").font(.headline)
                    Spacer()
                    Text("\(channels.count) configured").font(.caption).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(channels, id: \.self) { channel in
                        let count = records.filter { $0.channel == channel }.count
                        Button {
                            selectedChannel = channel
                            selectedRecord = records.first { $0.channel == channel }
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: count > 0 ? "film.stack" : "video.slash")
                                    .font(.system(size: 25))
                                Text("CAM \(channel)").font(.headline)
                                Text(isSearching ? "Searching…" : (count == 0 ? "No records found" : "\(count) archive segment\(count == 1 ? "" : "s")"))
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 86)
                            .padding(8)
                            .background(selectedChannel == channel ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedChannel == channel ? Color.accentColor : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !records.isEmpty {
                    Text("Recordings found on DVR").font(.headline)
                    ForEach(records) { record in
                        Button {
                            selectedChannel = record.channel
                            selectedRecord = record
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: selectedRecord?.id == record.id ? "checkmark.circle.fill" : "play.rectangle")
                                    .font(.title3)
                                    .foregroundStyle(selectedRecord?.id == record.id ? Color.accentColor : Color.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CAM \(record.channel) · \(clockFormatter.string(from: record.start)) – \(clockFormatter.string(from: record.end))")
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(record.fileType) · \(record.fileSize > 0 ? ByteCountFormatter.string(fromByteCount: record.fileSize, countStyle: .file) : "size not reported")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedRecord?.id == record.id ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("The DVR search returned these HDD recording entries. Video playback is not yet connected: this Kestrel firmware uses the proprietary quii:// archive transport and a Windows VPlugin transform. This build does not falsely display live RTSP as archive footage.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .navigationTitle("Playback")
        .task {
            guard !hasAutoSearched else { return }
            hasAutoSearched = true
            await searchArchive()
        }
    }

    @MainActor
    private func searchArchive() async {
        guard !isSearching else { return }
        isSearching = true
        statusIsError = false
        records = []
        selectedRecord = nil
        statusMessage = "Searching the DVR HDD index for all configured channels…"
        defer { isSearching = false }

        let calendar = Calendar.current
        let dateParts = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let startParts = calendar.dateComponents([.hour, .minute], from: startTime)
        let endParts = calendar.dateComponents([.hour, .minute], from: endTime)
        guard let start = calendar.date(from: DateComponents(year: dateParts.year, month: dateParts.month, day: dateParts.day, hour: startParts.hour, minute: startParts.minute)),
              let end = calendar.date(from: DateComponents(year: dateParts.year, month: dateParts.month, day: dateParts.day, hour: endParts.hour, minute: endParts.minute)), end >= start else {
            statusIsError = true
            statusMessage = "Check the time range: ‘To’ must be later than ‘From’ on the selected date."
            return
        }

        do {
            let found = try await archiveClient.searchRecordings(channels: channels, start: start, end: end, config: settings.config)
            records = found
            if found.isEmpty {
                statusMessage = "The DVR returned no matching archive entries for this date/time range. Try another time or confirm that recordings exist on the DVR."
            } else {
                selectedRecord = found.first { $0.channel == selectedChannel } ?? found.first
                statusMessage = "Found \(found.count) archive segment\(found.count == 1 ? "" : "s") across \(Set(found.map(\.channel)).count) camera(s). These entries are from the DVR index, not phone recordings."
            }
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }
}
