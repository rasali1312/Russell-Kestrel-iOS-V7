import AVFoundation
import Combine

final class AudioManager: NSObject, ObservableObject {
    @Published private(set) var enabled = false
    func setEnabled(_ value: Bool) {
        enabled = value
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(value)
    }
}
