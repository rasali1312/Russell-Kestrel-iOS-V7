import Foundation

struct KestrelConfiguration: Codable, Equatable {
    var host: String = "82.45.245.21"
    var webPort: Int = 8081
    var rtspPort: Int = 8554
    var username: String = "admin"
    var password: String = ""
    var maxChannels: Int = 16
}

struct CameraChannel: Identifiable, Hashable {
    let id: Int
    var name: String { "CAM \(id)" }
}

struct ArchiveQuery {
    var channel: Int
    var date: Date
}
