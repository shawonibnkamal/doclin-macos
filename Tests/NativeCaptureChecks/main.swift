import Foundation
import AVFoundation
import Speech

for _ in 0..<100 {
    let request = SFSpeechAudioBufferRecognitionRequest()
    let stream = DictationAudioStream(request)
    let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!, frameCapacity: 160)!
    buffer.frameLength = 160
    memset(buffer.floatChannelData![0], 0, 160 * MemoryLayout<Float>.size)
    precondition(stream.append(buffer))
    let group = DispatchGroup()
    for _ in 0..<4 {
        group.enter()
        DispatchQueue.global().async { _ = stream.append(buffer); group.leave() }
    }
    stream.endAudio(); stream.endAudio()
    group.wait()
    precondition(stream.isClosed)
    precondition(!stream.append(buffer))
}
let capture = DictationCapture()
let closed = DictationAudioStream(SFSpeechAudioBufferRecognitionRequest())
closed.endAudio()
let unexpected = DispatchSemaphore(value: 0)
capture.start(stream: closed, level: { _ in unexpected.signal() }, completion: { _ in unexpected.signal() })
let drained = DispatchSemaphore(value: 0)
capture.stop { drained.signal() }
precondition(drained.wait(timeout: .now() + 2) == .success)
precondition(unexpected.wait(timeout: .now()) == .timedOut)
print("PASS 100 concurrent append/close races, no buffers after release, idempotent close, canceled queued startup skipped")
