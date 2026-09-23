import AVFoundation

/// A quiet 70 ms cue using the selected media output, including AirPods.
@MainActor final class DictationStartCue {
    private var player: AVAudioPlayer?
    private let monitor = AudioRouteMonitor()
    init() { monitor.changed = { [weak self] in self?.stop() } }
    func stop() { player?.stop(); player = nil }
    func play() {
        stop()
        guard let route = AudioRoute.current(), let p = try? AVAudioPlayer(data: Self.wave),
              route.configure(p), AudioRoute.current()?.uid == route.uid else { return }
        p.volume = 0.25; player = p; _ = p.play()
    }
    private static let wave: Data = {
        let rate = 24000, count = 1680
        var data = Data()
        func text(_ s: String) { data.append(contentsOf: s.utf8) }
        func u16(_ n: UInt16) { var v = n.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ n: UInt32) { var v = n.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36 + count * 2)); text("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        text("data"); u32(UInt32(count * 2))
        for i in 0..<count {
            let t = Double(i) / Double(rate)
            let envelope = pow(sin(.pi * Double(i) / Double(count)), 2)
            let sample = Int16(9000 * envelope * sin(2 * .pi * (660 * t + 900 * t * t)))
            u16(UInt16(bitPattern: sample))
        }
        return data
    }()
}
