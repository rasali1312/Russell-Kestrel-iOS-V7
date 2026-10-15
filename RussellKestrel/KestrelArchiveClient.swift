import Foundation

struct ArchiveRecording: Identifiable, Hashable {
    let id: String
    let channel: Int
    let start: Date
    let end: Date
    let fileType: String
    let filename: String
    let fileSize: Int64
}

/// Native HTTP/XML client for the Kestrel CGI archive-search endpoints.
/// This searches the DVR HDD index; it does not pretend the proprietary `quii://`
/// playback transport is a standard HTTP/RTSP stream.
final class KestrelArchiveClient {
    enum ArchiveError: LocalizedError {
        case notConfigured
        case invalidURL
        case httpStatus(Int)
        case dvrError(String)
        case malformedResponse(String)
        case noSessionID

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Enter the DVR address, web port, username and password in Settings."
            case .invalidURL: return "The DVR address or web port is invalid."
            case .httpStatus(let code): return "The DVR returned HTTP \(code). Check the address, port and credentials."
            case .dvrError(let message): return "DVR archive search failed: \(message)"
            case .malformedResponse(let message): return "The DVR archive response could not be read: \(message)"
            case .noSessionID: return "The DVR accepted the search but did not return an archive session ID."
            }
        }
    }

    struct ProbeResult {
        let statusCode: Int
        let pageTitle: String?
        let requiresLegacyPlugin: Bool
    }

    private let session: URLSession
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 35
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func probe(host: String, port: Int, completion: @escaping (Result<ProbeResult, Error>) -> Void) {
        let cleanedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedHost.isEmpty, (1...65535).contains(port) else {
            completion(.failure(ArchiveError.notConfigured)); return
        }
        var components = URLComponents()
        components.scheme = "http"
        components.host = cleanedHost
        components.port = port
        components.path = "/"
        guard let url = components.url else { completion(.failure(ArchiveError.invalidURL)); return }
        session.dataTask(with: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, let data else {
                completion(.failure(URLError(.badServerResponse))); return
            }
            let page = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let lower = page.lowercased()
            let legacy = lower.contains("vplugin") || lower.contains("activex") || lower.contains("install control")
            let title = page.range(of: "<title[^>]*>(.*?)</title>", options: [.regularExpression, .caseInsensitive])
                .map { String(page[$0]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) }
            completion(.success(ProbeResult(statusCode: http.statusCode, pageTitle: title, requiresLegacyPlugin: legacy)))
        }.resume()
    }

    /// Searches the DVR's recording index for every requested channel and then
    /// retrieves the matching file metadata. It never records on the phone.
    func searchRecordings(channels: [Int], start: Date, end: Date, config: KestrelConfiguration) async throws -> [ArchiveRecording] {
        let host = config.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, (1...65535).contains(config.webPort), !config.username.isEmpty else {
            throw ArchiveError.notConfigured
        }
        guard end >= start else { throw ArchiveError.malformedResponse("The end time is earlier than the start time.") }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = config.webPort
        components.path = "/tdkcgi"
        guard let url = components.url else { throw ArchiveError.invalidURL }

        let channelList = Array(Set(channels.filter { $0 > 0 && $0 <= 32 })).sorted().map(String.init).joined(separator: ",")
        guard !channelList.isEmpty else { return [] }
        let rangeStart = xmlEscape(dateFormatter.string(from: start))
        let rangeEnd = xmlEscape(dateFormatter.string(from: end))
        let channelXML = xmlEscape(channelList)
        let streamXML = "all"
        let content = "<record><filetype>video</filetype><occurtype>all</occurtype><stream>\(streamXML)</stream><channel>\(channelXML)</channel><starttime>\(rangeStart)</starttime><endtime>\(rangeEnd)</endtime></record>"

        // Prefer the plain-XML API. If this firmware rejects it, try the newer
        // *Ex command names found in the Windows playback JavaScript.
        // Some *Ex responses are ActiveX-transformed datalist payloads; those cannot
        // be decoded unless the vendor's ITransformToPlaybackXml algorithm is known.
        let sessionID: String
        let messageCommand: String
        do {
            let legacySession = try await post(command: "g.rec.session", content: content, to: url, config: config)
            try checkDVRResponse(legacySession)
            guard let id = firstValue(named: "id", in: legacySession), !id.isEmpty else {
                throw ArchiveError.noSessionID
            }
            sessionID = id
            messageCommand = "g.rec.msg"
        } catch {
            let extendedSession = try await post(command: "get.record.sessionEx", content: content, to: url, config: config)
            try checkDVRResponse(extendedSession)
            guard let id = firstValue(named: "id", in: extendedSession), !id.isEmpty else {
                throw ArchiveError.dvrError("Both legacy and extended session search failed. Last error: \(error.localizedDescription)")
            }
            sessionID = id
            messageCommand = "get.record.messageEx"
        }

        let messageXML = try await post(command: messageCommand, content: "<record><id>\(xmlEscape(sessionID))</id></record>", to: url, config: config)
        try checkDVRResponse(messageXML)
        let parsed = parseRecordRows(messageXML)
        if parsed.isEmpty, messageXML.range(of: "<datalist", options: .caseInsensitive) != nil {
            throw ArchiveError.malformedResponse("This firmware returned an encoded record list that normally requires the Windows VPlugin transform. The search request reached the DVR, but the iOS decoder for that payload is not available yet.")
        }
        return parsed.filter { $0.channel > 0 && channels.contains($0.channel) }
            .sorted { $0.start < $1.start }
    }

    private func post(command: String, content: String, to url: URL, config: KestrelConfiguration) async throws -> String {
        let user = xmlEscape(config.username)
        let password = xmlEscape(config.password)
        let body = "<?xml version=\"1.0\" encoding=\"utf-8\"?><envelope><header><security>username</security><username>\(user)</username><password>\(password)</password></header><body><command>\(xmlEscape(command))</command><content>\(content)</content></body></envelope>"
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.httpBody = body.data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else { throw ArchiveError.httpStatus(http.statusCode) }
        guard let text = String(data: data, encoding: .utf8) else { throw ArchiveError.malformedResponse("Response is not UTF-8 XML.") }
        return text
    }

    private func checkDVRResponse(_ xml: String) throws {
        guard let code = firstValue(named: "error", in: xml) else { return }
        if code != "0" {
            throw ArchiveError.dvrError("error code \(code)")
        }
    }

    private func parseRecordRows(_ xml: String) -> [ArchiveRecording] {
        let blocks = xml.components(separatedBy: "<data>").dropFirst().compactMap { $0.components(separatedBy: "</data>").first }
        var result: [ArchiveRecording] = []
        for block in blocks {
            guard let channelText = firstValue(named: "channel", in: block),
                  let channel = Int(channelText),
                  let startText = firstValue(named: "starttime", in: block),
                  let endText = firstValue(named: "endtime", in: block),
                  let start = parseDVRDate(startText), let end = parseDVRDate(endText) else { continue }
            let name = firstValue(named: "filename", in: block) ?? ""
            let type = firstValue(named: "occurtype", in: block) ?? "unknown"
            let size = Int64(firstValue(named: "filesize", in: block) ?? "0") ?? 0
            result.append(ArchiveRecording(id: "\(channel)-\(start.timeIntervalSince1970)-\(name)", channel: channel, start: start, end: end, fileType: type, filename: name, fileSize: size))
        }
        return result
    }

    private func firstValue(named tag: String, in xml: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: tag)
        let pattern = "<\\s*\(escaped)(?:\\s[^>]*)?>(.*?)</\\s*\(escaped)\\s*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              let range = Range(match.range(at: 1), in: xml) else { return nil }
        return String(xml[range]).replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDVRDate(_ raw: String) -> Date? {
        let normalized = raw.replacingOccurrences(of: "t", with: "T").replacingOccurrences(of: "z", with: "")
        if let date = dateFormatter.date(from: normalized) { return date }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_GB_POSIX")
        fallback.timeZone = .current
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS"] {
            fallback.dateFormat = format
            if let date = fallback.date(from: normalized) { return date }
        }
        return nil
    }

    private func xmlEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
