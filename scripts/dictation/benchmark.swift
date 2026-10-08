import Foundation
import AVFoundation
import Speech
import DoclinCore

// Compile with the app's capture adapter; no microphone, credentials, or cloud calls.
struct Sample: Codable { let id: String; let audio: String; let expected: String }
struct Measurement: Codable {
    let id: String; let expected: String; let actual: String
    let wordErrors: Int; let referenceWords: Int
    let startupMS: Int; let releaseToFinalMS: Int
}
func words(_ value: String) -> [String] {
    value.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
}
func distance(_ a: [String], _ b: [String]) -> Int {
    var row = Array(0...b.count)
    for (i, x) in a.enumerated() {
        var next = [i + 1]
        for (j, y) in b.enumerated() { next.append(min(next[j] + 1, row[j + 1] + 1, row[j] + (x == y ? 0 : 1))) }
        row = next
    }
    return row[b.count]
}
@main struct Benchmark {
    @MainActor static func main() async throws {
        guard #available(macOS 26.0, *), CommandLine.arguments.count == 2 else {
            print("Usage: dictation-benchmark manifest.json (macOS 26+)"); return
        }
        let manifest = URL(fileURLWithPath: CommandLine.arguments[1])
        let samples = try JSONDecoder().decode([Sample].self, from: Data(contentsOf: manifest))
        let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))!
        _ = try await AssetInventory.reserve(locale: locale)
        var measurements: [Measurement] = []
        for sample in samples {
            let file = try AVAudioFile(forReading: manifest.deletingLastPathComponent().appendingPathComponent(sample.audio))
            let began = ProcessInfo.processInfo.systemUptime
            let session = try await ModernDictation.prepare(locale: Locale(identifier: "en-US"), terms: ["Doclin", "Codex", "Claude", "Succession AI"]) { _ in }
            let startupMS = Int((ProcessInfo.processInfo.systemUptime - began) * 1000)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 1024) else { throw ModernDictation.PreparationError.unavailable }
            while file.framePosition < file.length {
                try file.read(into: buffer)
                guard session.stream.append(buffer) else { throw ModernDictation.PreparationError.unavailable }
                try await Task.sleep(nanoseconds: UInt64(Double(buffer.frameLength) / file.processingFormat.sampleRate * 1_000_000_000))
            }
            let released = ProcessInfo.processInfo.systemUptime
            let actual = try await session.finish()
            measurements.append(Measurement(id: sample.id, expected: sample.expected, actual: actual,
                wordErrors: distance(words(sample.expected), words(actual)), referenceWords: words(sample.expected).count,
                startupMS: startupMS, releaseToFinalMS: Int((ProcessInfo.processInfo.systemUptime - released) * 1000)))
        }
        _ = await AssetInventory.release(reservedLocale: locale)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(measurements), as: UTF8.self))
    }
}
