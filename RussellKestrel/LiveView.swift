import SwiftUI
import WebKit

struct LiveView: View {
    @EnvironmentObject var settings: SettingsStore
    @Binding var selectedChannel: Int
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Russell Kestrel V7").font(.title2.bold())
                    Spacer()
                    Text(settings.config.host.isEmpty ? "Not configured" : settings.config.host)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(1...min(settings.config.maxChannels, 16), id: \.self) { channel in
                        Button {
                            selectedChannel = channel
                        } label: {
                            KestrelWebView(url: settings.liveURL(channel: channel))
                                .frame(minHeight: 150)
                                .overlay(alignment: .bottomLeading) {
                                    Text("CAM \(channel)").font(.caption.bold()).padding(6)
                                        .background(.black.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedChannel == channel ? .primary : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

extension SettingsStore {
    func liveURL(channel: Int) -> URL? {
        guard !config.host.isEmpty else { return nil }
        var c = URLComponents(); c.scheme = "http"; c.host = config.host; c.port = config.webPort
        c.path = "/"; c.queryItems = [URLQueryItem(name: "channel", value: String(channel))]
        return c.url
    }
    func archiveURL(channel: Int, date: Date) -> URL? {
        guard !config.host.isEmpty else { return nil }
        var c = URLComponents(); c.scheme = "http"; c.host = config.host; c.port = config.webPort
        c.path = "/"; c.queryItems = [URLQueryItem(name: "channel", value: String(channel)), URLQueryItem(name: "playback", value: "1")]
        return c.url
    }
}

struct KestrelWebView: UIViewRepresentable {
    let url: URL?
    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        w.scrollView.isScrollEnabled = false
        w.allowsBackForwardNavigationGestures = false
        return w
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        guard let url else { return }
        if view.url != url { view.load(URLRequest(url: url)) }
    }
}
