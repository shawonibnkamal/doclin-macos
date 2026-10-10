import AVFoundation
import Speech
import DoclinCore

/// Seal the audio stream at release without waiting for hardware teardown.
/// Closing and appending share a lock, so every accepted buffer precedes endAudio.
protocol DictationAudioSink: Sendable {
    var isClosed: Bool { get }
    func append(_ buffer: AVAudioPCMBuffer) -> Bool
    func endAudio()
}

final class DictationAudioStream: DictationAudioSink, @unchecked Sendable {
    private let lock = NSLock()
    private var closed = false
    private let request: SFSpeechAudioBufferRecognitionRequest
    init(_ request: SFSpeechAudioBufferRecognitionRequest) { self.request = request }
    var isClosed: Bool { lock.lock(); defer { lock.unlock() }; return closed }
    func append(_ buffer: AVAudioPCMBuffer) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return false }
        request.append(buffer); return true
    }
    func endAudio() {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        closed = true; request.endAudio()
    }
}

/// Serial audio ownership keeps slow device setup/teardown off the UI thread.
/// The engine is stopped between holds; it never listens in the background.
final class DictationCapture: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.doclin.dictation.capture", qos: .userInitiated)
    private var engine: AVAudioEngine?
    private var tapped = false

    func start(stream: any DictationAudioSink, level: @escaping @Sendable (Float) -> Void,
               completion: @escaping @Sendable (String?) -> Void) {
        queue.async { [self] in
            do {
                guard !stream.isClosed else { return }
                let engine = self.engine ?? AVAudioEngine(); self.engine = engine
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else {
                    throw NSError(domain: "DoclinAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone is unavailable."])
                }
                input.installTap(onBus: 0, bufferSize: 512, format: format) { buffer, _ in
                    guard stream.append(buffer) else { return }
                    if let values = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                        var sum: Float = 0
                        for i in 0..<Int(buffer.frameLength) { sum += values[i] * values[i] }
                        level(AudioMeter.level(rms: sqrt(sum / Float(buffer.frameLength))))
                    }
                }
                tapped = true
                guard !stream.isClosed else { stopEngine(); return }
                engine.prepare()
                guard !stream.isClosed else { stopEngine(); return }
                try engine.start()
                guard !stream.isClosed else { stopEngine(); return }
                completion(nil)
            } catch {
                stopEngine(); engine = nil
                completion(error.localizedDescription)
            }
        }
    }
    func stop(completion: (@Sendable () -> Void)? = nil) {
        queue.async { [self] in stopEngine(); completion?() }
    }
    private func stopEngine() {
        guard let engine else { return }
        if engine.isRunning { engine.stop() }
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
    }
}
