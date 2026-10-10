import AVFoundation
import Speech
import DoclinCore

/// Owns conversion and stream closure together, so release cannot truncate an accepted buffer.
@available(macOS 26.0, *)
final class AnalyzerAudioStream: DictationAudioSink, @unchecked Sendable {
    private let lock = NSLock()
    private var closed = false
    private let format: AVAudioFormat
    private var converter: AVAudioConverter?
    let inputs: AsyncThrowingStream<AnalyzerInput, Error>
    private let continuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation
    init(format: AVAudioFormat) {
        self.format = format
        (inputs, continuation) = AsyncThrowingStream.makeStream()
    }
    var isClosed: Bool { lock.lock(); defer { lock.unlock() }; return closed }
    func append(_ buffer: AVAudioPCMBuffer) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return false }
        // Engine tap buffers are reused. Conversion produces an owned buffer for the async consumer.
        if converter == nil { converter = AVAudioConverter(from: buffer.format, to: format) }
        guard let converter else { close(error: ConversionError.failed); return false }
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { close(error: ConversionError.failed); return false }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            if supplied { state.pointee = .noDataNow; return nil }
            supplied = true; state.pointee = .haveData; return buffer
        }
        guard status != .error, error == nil else { close(error: error ?? ConversionError.failed as NSError); return false }
        if output.frameLength > 0 { continuation.yield(AnalyzerInput(buffer: output)) }
        return true
    }
    func endAudio() { lock.lock(); defer { lock.unlock() }; close(error: nil) }
    private func close(error: Error?) {
        guard !closed else { return }; closed = true
        continuation.finish(throwing: error)
    }
    enum ConversionError: Error { case failed }
}

/// No network transcription. Asset preparation is separate from microphone capture.
@available(macOS 26.0, *)
@MainActor final class ModernDictation {
    private let analyzer: SpeechAnalyzer
    let stream: AnalyzerAudioStream
    private var resultsTask: Task<Void, Error>?
    private var buffer = TimedTranscript()
    private var canceled = false
    var onUpdate: (String) -> Void = { _ in }
    private init(analyzer: SpeechAnalyzer, stream: AnalyzerAudioStream) {
        self.analyzer = analyzer; self.stream = stream
    }
    static func prepare(locale: Locale, terms: [String], update: @escaping (String) -> Void) async throws -> ModernDictation {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: locale) else { throw PreparationError.unavailable }
        try Task.checkCancellation()
        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
        guard await AssetInventory.status(forModules: [transcriber]) == .installed else { throw PreparationError.unavailable }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else { throw PreparationError.unavailable }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let context = AnalysisContext(); context.contextualStrings[.general] = terms
        try await analyzer.setContext(context)
        try await analyzer.prepareToAnalyze(in: format)
        try Task.checkCancellation()
        let session = ModernDictation(analyzer: analyzer, stream: AnalyzerAudioStream(format: format))
        session.onUpdate = update
        session.resultsTask = Task { [weak session] in
            for try await result in transcriber.results {
                try Task.checkCancellation()
                guard let session, !session.canceled else { return }
                let text = session.buffer.update(String(result.text.characters), start: result.range.start.seconds,
                                                 end: result.range.end.seconds, final: result.isFinal)
                session.onUpdate(text)
            }
        }
        do { try await analyzer.start(inputSequence: session.stream.inputs) }
        catch { session.cancel(); throw error }
        return session
    }
    func finish() async throws -> String {
        stream.endAudio()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await resultsTask?.value
        try Task.checkCancellation()
        guard !canceled else { throw CancellationError() }
        return buffer.text
    }
    func cancel() {
        canceled = true; stream.endAudio(); resultsTask?.cancel()
        Task { await analyzer.cancelAndFinishNow() }
    }
    enum PreparationError: Error { case unavailable }
}
