import SwiftUI
import WebKit

struct LiveView: View {
    @EnvironmentObject var settings: SettingsStore
    @Binding var selectedChannel: Int
    @State private var showCamera = false
    private var channels: Range<Int> { 1..<(max(0, min(settings.config.maxChannels, 16)) + 1) }
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
                    ForEach(channels, id: \.self) { channel in
                        Button {
                            selectedChannel = channel
                            showCamera = true
                        } label: {
                            KestrelWebView(url: settings.liveURL(channel: channel))
                                .allowsHitTesting(false)
                                .frame(minHeight: 150)
                                .overlay(alignment: .bottomLeading) {
                                    Text("CAM \(channel)").font(.caption.bold()).padding(6)
                                        .background(.black.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedChannel == channel ? .primary : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("CAM \(channel)")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .fullScreenCover(isPresented: $showCamera) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                TabView(selection: $selectedChannel) {
                    ForEach(channels, id: \.self) { channel in
                        Group {
                            if channel == selectedChannel {
                                ZoomableCamera(url: settings.liveURL(channel: channel))
                            } else {
                                Color.black
                            }
                        }
                        .tag(channel)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                Button {
                    showCamera = false
                } label: {
                    Label("Close", systemImage: "xmark.circle.fill")
                        .padding(12)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.7), in: Capsule())
                }
                .padding()
            }
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

private struct ZoomableCamera: UIViewRepresentable {
    let url: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.bouncesZoom = false
        scroll.panGestureRecognizer.isEnabled = false
        scroll.delegate = context.coordinator
        let video = WKWebView()
        video.isUserInteractionEnabled = false
        video.scrollView.isScrollEnabled = false
        video.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(video)
        NSLayoutConstraint.activate([
            video.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            video.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            video.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            video.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            video.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            video.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        context.coordinator.video = video
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        guard context.coordinator.requestedURL != url else { return }
        context.coordinator.requestedURL = url
        if let url { context.coordinator.video?.load(URLRequest(url: url)) }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var video: WKWebView?
        var requestedURL: URL?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { video }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let zoom = scrollView.zoomScale
            scrollView.panGestureRecognizer.isEnabled = zoom > 1.01
        }
    }
}
